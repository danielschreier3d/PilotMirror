"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { supabase } from "@/lib/supabase";
import { runAnalysis } from "@/lib/analysis";
import type { FeedbackLink, AnalysisResult } from "@/lib/types";
import { getFeedbackURL } from "@/lib/types";
import Link from "next/link";

const MIN_RESPONSES = 5;
const TARGET_RESPONSES = 12;

function t(de: string, en: string, isGerman: boolean) { return isGerman ? de : en; }

export default function DashboardPage() {
  const { user, isGerman } = useAuth();
  const router = useRouter();

  const [feedbackLink, setFeedbackLink]   = useState<FeedbackLink | null>(null);
  const [selfDone, setSelfDone]           = useState(false);
  const [analysisResult, setAnalysisResult] = useState<AnalysisResult | null>(null);
  const [isCreatingLink, setIsCreatingLink] = useState(false);
  const [isAnalyzing, setIsAnalyzing]     = useState(false);
  const [analysisError, setAnalysisError] = useState<string | null>(null);
  const [copied, setCopied]               = useState(false);
  const [interviewRuns, setInterviewRuns] = useState(0);
  const [showProfile, setShowProfile]     = useState(false);
  const [isRefreshing, setIsRefreshing]   = useState(false);

  // ── Load persisted data on mount ──────────────────────────────────────────
  useEffect(() => {
    // Interview run count
    setInterviewRuns(parseInt(localStorage.getItem("pm_interview_run_count") ?? "0", 10));

    // Analysis result
    const cached = localStorage.getItem("pm_analysis_result_v1");
    if (cached) { try { setAnalysisResult(JSON.parse(cached)); } catch { /* ignore */ } }

    // Feedback link
    const cachedLink = localStorage.getItem("pm_feedback_link");
    if (cachedLink) { try { setFeedbackLink(JSON.parse(cachedLink)); } catch { /* ignore */ } }

    // Self responses
    const sr = localStorage.getItem("pm_self_responses");
    if (sr) { try { setSelfDone(Object.keys(JSON.parse(sr)).length >= 5); } catch { /* ignore */ } }
  }, []);

  // ── Load from Supabase ────────────────────────────────────────────────────
  const loadFromSupabase = useCallback(async () => {
    if (!user) return;
    setIsRefreshing(true);
    try {
      // Get ALL sessions for this user (iOS and web may have created different sessions)
      const { data: sessions } = await supabase
        .from("assessment_sessions").select("id").eq("candidate_id", user.id);
      if (!sessions || sessions.length === 0) { setIsRefreshing(false); return; }

      const sessionIds = sessions.map((s: { id: string }) => s.id);
      // Use most-recently-inserted session as primary (for new writes)
      localStorage.setItem("pm_session_id", sessionIds[0]);

      // Self responses count — across ALL sessions
      const { count } = await supabase
        .from("self_responses").select("*", { count: "exact", head: true })
        .in("session_id", sessionIds);
      setSelfDone((count ?? 0) >= 5);

      // Feedback link — across ALL sessions, pick the one with most responses
      const { data: links } = await supabase
        .from("feedback_links").select("*").in("session_id", sessionIds)
        .order("response_count", { ascending: false }).limit(1);
      const link = links?.[0];
      if (link) {
        const fl: FeedbackLink = {
          id: link.id, sessionId: link.session_id, token: link.token,
          responseCount: link.response_count, createdAt: link.created_at,
        };
        setFeedbackLink(fl);
        localStorage.setItem("pm_feedback_link", JSON.stringify(fl));
      }

      // Analysis result — across ALL sessions
      const { data: analyses } = await supabase
        .from("analysis_results").select("*").in("session_id", sessionIds).limit(1);
      const analysis = analyses?.[0];
      if (analysis) {
        function safeJson<T>(s: string | null): T[] {
          if (!s) return [];
          try { return JSON.parse(s); } catch { return []; }
        }
        const ar: AnalysisResult = {
          personalitySummary: analysis.personality_summary ?? "",
          perceivedStrengths: analysis.strengths ?? [],
          possibleWeaknesses: analysis.weaknesses ?? [],
          selfVsOthers: analysis.self_vs_others ?? "",
          assessmentAdvice: analysis.assessment_advice ?? "",
          groupExerciseTips: analysis.group_exercise_tips ?? [],
          interviewTips: analysis.interview_tips ?? [],
          decisionMakingTips: analysis.decision_making_tips ?? [],
          selfAwarenessTips: analysis.self_awareness_tips ?? [],
          comparisonAreas: safeJson(analysis.comparison_areas),
          traitStats: safeJson(analysis.trait_stats),
          forcedChoiceStats: safeJson(analysis.forced_choice_stats),
          openTextResponses: analysis.open_text_responses ?? [],
          respondentCount: analysis.respondent_count_at_analysis ?? 0,
          generatedAt: analysis.generated_at ?? new Date().toISOString(),
        };
        setAnalysisResult(ar);
        localStorage.setItem("pm_analysis_result_v1", JSON.stringify(ar));
      }
    } finally {
      setIsRefreshing(false);
    }
  }, [user]);

  useEffect(() => {
    if (user) loadFromSupabase();
  }, [user, loadFromSupabase]);

  // ── Derived state ─────────────────────────────────────────────────────────
  const responseCount   = feedbackLink?.responseCount ?? 0;
  const linkDone        = responseCount >= MIN_RESPONSES;
  const canAnalyze      = selfDone && linkDone;
  const interviewDone   = interviewRuns >= 3;
  const hasNewResponses = analysisResult != null && responseCount > analysisResult.respondentCount;
  const reportUpToDate  = analysisResult != null && analysisResult.personalitySummary.trim().length > 0
                          && responseCount === analysisResult.respondentCount;

  const progress = Math.min(
    (selfDone ? 1/3 : 0) +
    Math.min(responseCount, 5) / 5 * (1/3) +
    Math.min(interviewRuns, 3) / 3 * (1/3),
    1
  );
  const isFullyPrepared = selfDone && linkDone && interviewDone;

  // ── Create feedback link ──────────────────────────────────────────────────
  async function createLink() {
    if (!user) return;
    setIsCreatingLink(true);
    try {
      let sessionId = localStorage.getItem("pm_session_id");
      if (!sessionId) {
        // Create session
        const newId = crypto.randomUUID();
        await supabase.from("assessment_sessions").insert({ id: newId, candidate_id: user.id });
        sessionId = newId;
        localStorage.setItem("pm_session_id", newId);
      }
      const token  = Array.from(crypto.getRandomValues(new Uint8Array(5)))
                      .map(b => b.toString(36).padStart(2,"0")).join("").slice(0,10);
      const linkId = crypto.randomUUID();
      await supabase.from("feedback_links").insert({
        id: linkId, session_id: sessionId, token, response_count: 0,
      });
      const fl: FeedbackLink = { id: linkId, sessionId, token, responseCount: 0, createdAt: new Date().toISOString() };
      setFeedbackLink(fl);
      localStorage.setItem("pm_feedback_link", JSON.stringify(fl));
    } finally {
      setIsCreatingLink(false);
    }
  }

  // ── Run AI analysis ────────────────────────────────────────────────────────
  async function triggerAnalysis() {
    if (!user) return;
    setIsAnalyzing(true); setAnalysisError(null);
    try {
      const result = await runAnalysis(
        user.assessmentType ?? "General Pilot Assessment",
        user.id,
        user.flightLicenses ?? [],
        analysisResult
      );
      setAnalysisResult(result);
      localStorage.setItem("pm_analysis_result_v1", JSON.stringify(result));

      // Persist to Supabase so it survives across devices/sessions
      const sessionId = localStorage.getItem("pm_session_id");
      if (sessionId) {
        await supabase.from("analysis_results").upsert({
          session_id:                 sessionId,
          personality_summary:        result.personalitySummary,
          strengths:                  result.perceivedStrengths,
          weaknesses:                 result.possibleWeaknesses,
          self_vs_others:             result.selfVsOthers,
          assessment_advice:          result.assessmentAdvice,
          group_exercise_tips:        result.groupExerciseTips,
          interview_tips:             result.interviewTips,
          decision_making_tips:       result.decisionMakingTips,
          self_awareness_tips:        result.selfAwarenessTips,
          comparison_areas:           JSON.stringify(result.comparisonAreas),
          trait_stats:                JSON.stringify(result.traitStats),
          forced_choice_stats:        JSON.stringify(result.forcedChoiceStats),
          open_text_responses:        result.openTextResponses,
          respondent_count_at_analysis: result.respondentCount,
        }, { onConflict: "session_id" });
      }

      router.push("/results");
    } catch (e: unknown) {
      setAnalysisError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setIsAnalyzing(false);
    }
  }

  // ── Copy link ─────────────────────────────────────────────────────────────
  function copyLink() {
    if (!feedbackLink) return;
    navigator.clipboard.writeText(getFeedbackURL(feedbackLink.token));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  // ── Share helpers ─────────────────────────────────────────────────────────
  function shareWhatsApp() {
    if (!feedbackLink) return;
    const url = getFeedbackURL(feedbackLink.token);
    const msg = isGerman
      ? `Hey! Kannst du mir kurz helfen? Ich bereite mich auf mein Pilotenauswahlverfahren vor und wäre dir sehr dankbar, wenn du diesen kurzen, anonymen Fragebogen ausfüllst (ca. 3 Min.):\n\n${url}`
      : `Hey! Could you help me out? I'm preparing for my pilot assessment and would love your honest, anonymous feedback – takes about 3 minutes:\n\n${url}`;
    window.open(`https://wa.me/?text=${encodeURIComponent(msg)}`, "_blank");
  }

  function shareMail() {
    if (!feedbackLink) return;
    const url = getFeedbackURL(feedbackLink.token);
    const sub = isGerman ? "Kurze Bitte: Anonymes Feedback für mein Pilotenauswahlverfahren" : "Quick Request: Anonymous Feedback for My Pilot Assessment";
    const body = isGerman
      ? `Hallo,\n\nIch bereite mich auf mein Pilotenauswahlverfahren vor. Kannst du mir kurz helfen?\n\n${url}\n\nDanke!`
      : `Hi,\n\nI'm preparing for my pilot assessment. Could you please fill out this quick anonymous survey?\n\n${url}\n\nThank you!`;
    window.open(`mailto:?subject=${encodeURIComponent(sub)}&body=${encodeURIComponent(body)}`);
  }

  function shareNative() {
    if (!feedbackLink || !navigator.share) return;
    navigator.share({ url: getFeedbackURL(feedbackLink.token), title: "PilotMirror Feedback" });
  }

  // ── Refresh ───────────────────────────────────────────────────────────────
  async function refreshStatus() {
    if (!feedbackLink) return;
    setIsRefreshing(true);
    try {
      const { data } = await supabase
        .from("feedback_links").select("response_count").eq("id", feedbackLink.id).single();
      if (data) {
        const updated = { ...feedbackLink, responseCount: data.response_count as number };
        setFeedbackLink(updated);
        localStorage.setItem("pm_feedback_link", JSON.stringify(updated));
      }
    } finally {
      setIsRefreshing(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RENDER
  // ─────────────────────────────────────────────────────────────────────────

  return (
    <div className="relative">
      {/* Nav bar */}
      <div className="sticky top-0 z-40 px-4 pt-safe-top"
        style={{ background: "var(--app-bg)", borderBottom: "1px solid var(--app-border)", paddingBottom: 8, paddingTop: "max(env(safe-area-inset-top, 12px), 12px)" }}>
        <div className="flex items-center justify-between">
          <h1 className="text-xl font-bold" style={{ color: "var(--app-primary)" }}>Dashboard</h1>
          <button onClick={() => router.push("/profile")}
            className="w-9 h-9 flex items-center justify-center rounded-full"
            style={{ background: "var(--app-input)" }}>
            <span className="text-lg">👤</span>
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="px-4 py-4 space-y-4 pb-safe">

        {/* Header */}
        <div className="text-center space-y-2">
          <h2 className="text-2xl font-bold" style={{ color: "var(--app-primary)", letterSpacing: "-0.3px" }}>
            {t("Dein Assessment-Plan", "Your Assessment Plan", isGerman)}
          </h2>
          {user?.assessmentType && (
            <span className="inline-block text-xs px-3 py-1 rounded-full font-semibold"
              style={{ background: "rgba(74,158,248,0.15)", color: "#4A9EF8" }}>
              {user.assessmentType}
            </span>
          )}
        </div>

        {/* Preparation card */}
        <PrepCard progress={progress} selfDone={selfDone} linkDone={linkDone}
          interviewDone={interviewDone} isFullyPrepared={isFullyPrepared}
          isGerman={isGerman} responseCount={responseCount} interviewRuns={interviewRuns} />

        {/* Step 1 */}
        <StepCard number={1} done={selfDone} locked={false}
          title={t("Self-Assessment ausfüllen","Complete Self-Assessment",isGerman)}
          subtitle={selfDone
            ? t("Abgeschlossen","Completed",isGerman)
            : t("Beantworte denselben Fragebogen über dich selbst","Answer the same questionnaire about yourself",isGerman)}>
          {!selfDone && (
            <ActionButton label={t("Jetzt starten","Start now",isGerman)} icon="📋"
              onClick={() => router.push("/survey")} />
          )}
        </StepCard>

        {/* Step 2 */}
        <StepCard number={2} done={linkDone} locked={false}
          title={t("Link an mindestens 5 Personen senden","Send link to at least 5 people",isGerman)}
          subtitle={
            feedbackLink == null
              ? t("Erstelle deinen persönlichen Feedback-Link","Create your personal feedback link",isGerman)
              : linkDone
                ? t(`${responseCount}/${TARGET_RESPONSES} Rückmeldungen — Report freigeschaltet!`,`${responseCount}/${TARGET_RESPONSES} responses — report unlocked!`,isGerman)
                : t(`${responseCount} von ${MIN_RESPONSES} Minimum — ${MIN_RESPONSES - responseCount} fehlen noch`,`${responseCount} of ${MIN_RESPONSES} minimum — ${MIN_RESPONSES - responseCount} missing`,isGerman)
          }>
          {feedbackLink ? (
            <div className="space-y-3">
              <ResponseProgressBar responseCount={responseCount} isGerman={isGerman} />
              {/* URL row */}
              <div className="flex items-center gap-2 px-3 py-2 rounded-xl"
                style={{ background: "var(--app-card)", border: "1px solid var(--app-border)" }}>
                <span className="text-xs font-mono truncate flex-1" style={{ color: "#4A9EF8" }}>
                  {getFeedbackURL(feedbackLink.token)}
                </span>
                <button onClick={copyLink} className="text-lg flex-shrink-0">
                  {copied ? "✅" : "📋"}
                </button>
              </div>
              {/* Share buttons */}
              <div className="flex gap-2">
                <ShareIconButton label="WhatsApp" icon="💬" onClick={shareWhatsApp} />
                <ShareIconButton label="E-Mail"   icon="✉️"  onClick={shareMail} />
                <ShareIconButton label={t("Aktualisieren","Refresh",isGerman)} icon={isRefreshing ? "⏳" : "🔄"} onClick={refreshStatus} />
                {typeof navigator !== "undefined" && "share" in navigator && (
                  <ShareIconButton label={t("Mehr","More",isGerman)} icon="⬆️" onClick={shareNative} />
                )}
              </div>
            </div>
          ) : (
            <div className="space-y-2">
              <ActionButton
                label={isCreatingLink ? t("Wird erstellt…","Creating…",isGerman) : t("Link erstellen","Create link",isGerman)}
                icon="🔗"
                disabled={isCreatingLink || !selfDone}
                onClick={createLink} />
              {!selfDone && (
                <p className="text-xs text-center" style={{ color: "var(--app-tertiary)" }}>
                  {t("Erst Self-Assessment abschließen","Complete self-assessment first",isGerman)}
                </p>
              )}
            </div>
          )}
        </StepCard>

        {/* Step 3 */}
        <StepCard number={3} done={!!analysisResult?.personalitySummary && !hasNewResponses} locked={!canAnalyze}
          title={t("KI-Analyse starten","Start AI Analysis",isGerman)}
          subtitle={
            analysisResult?.personalitySummary && !hasNewResponses
              ? t("Report ist aktuell","Report is up to date",isGerman)
              : hasNewResponses
                ? t(`${responseCount - (analysisResult?.respondentCount ?? 0)} neue Antworten — Aktualisierung empfohlen`,
                    `${responseCount - (analysisResult?.respondentCount ?? 0)} new responses — update recommended`,isGerman)
                : canAnalyze
                  ? t("Alle Voraussetzungen erfüllt","All requirements met",isGerman)
                  : t("Verfügbar sobald Self-Assessment und 5 Rückmeldungen vorliegen","Available once self-assessment and 5 responses are complete",isGerman)
          }>
          {canAnalyze && !(analysisResult?.personalitySummary && !hasNewResponses) && (
            <ActionButton
              label={isAnalyzing
                ? t("Analysiere…","Analyzing…",isGerman)
                : hasNewResponses
                  ? t("Report aktualisieren","Update report",isGerman)
                  : t("Report erstellen","Generate report",isGerman)}
              icon="✨" gradient disabled={isAnalyzing}
              onClick={triggerAnalysis} />
          )}
          {analysisResult?.personalitySummary && (
            <ActionButton label={t("Report anzeigen","View report",isGerman)} icon="📄"
              onClick={() => router.push("/results")} />
          )}
          {analysisError && (
            <p className="text-xs" style={{ color: "#FF6B6B" }}>{analysisError}</p>
          )}
        </StepCard>

        {/* Step 4 */}
        <StepCard number={4} done={interviewDone} locked={!analysisResult}
          title={t("Interview simulieren","Simulate Interview",isGerman)}
          subtitle={
            !analysisResult
              ? t("Verfügbar nach KI-Analyse","Available after AI analysis",isGerman)
              : interviewRuns === 0
                ? t("Noch kein Durchgang absolviert","No run completed yet",isGerman)
                : interviewRuns < 3
                  ? t(`${interviewRuns} von 3 Durchgängen absolviert`,`${interviewRuns} of 3 runs completed`,isGerman)
                  : t("Mindestens 3 Durchgänge absolviert ✓","At least 3 runs completed ✓",isGerman)
          }>
          <ActionButton
            label={t(interviewRuns === 0 ? "Interview starten" : "Weiteres Interview starten",
                     interviewRuns === 0 ? "Start interview"  : "Start another interview", isGerman)}
            icon="🎤" onClick={() => router.push("/interview")} />
          {interviewRuns > 0 && (
            <div className="flex items-center gap-2 mt-1">
              {[0,1,2].map((i) => (
                <div key={i} className="w-2 h-2 rounded-full"
                  style={{ background: i < interviewRuns ? "#4A9EF8" : "var(--app-border)" }} />
              ))}
              <span className="text-xs" style={{ color: interviewDone ? "#4A9EF8" : "var(--app-secondary)" }}>
                {Math.min(interviewRuns,3)}/3 {isGerman ? "Durchgänge" : "runs"}
              </span>
            </div>
          )}
        </StepCard>

        <div className="h-4" />
      </div>

      {showProfile && (
        <div className="fixed inset-0 z-50 bg-black/50" onClick={() => setShowProfile(false)} />
      )}
    </div>
  );
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function PrepCard({ progress, selfDone, linkDone, interviewDone, isFullyPrepared, isGerman, responseCount, interviewRuns }: {
  progress: number; selfDone: boolean; linkDone: boolean; interviewDone: boolean;
  isFullyPrepared: boolean; isGerman: boolean; responseCount: number; interviewRuns: number;
}) {
  return (
    <div className="rounded-2xl p-4 space-y-3"
      style={{
        background: "var(--app-card)",
        border: `1px solid ${isFullyPrepared ? "rgba(74,158,248,0.4)" : "var(--app-border)"}`,
      }}>
      <div className="flex items-center justify-between">
        <div>
          <div className="font-bold text-sm" style={{ color: "var(--app-primary)" }}>
            {isFullyPrepared
              ? (isGerman ? "Bestmöglich vorbereitet!" : "Best possible preparation!")
              : (isGerman ? "Dein Vorbereitungsstand" : "Your preparation status")}
          </div>
          <div className="text-xs mt-0.5" style={{ color: "var(--app-secondary)" }}>
            {isFullyPrepared
              ? (isGerman ? "Du hast alle Schritte abgeschlossen." : "You have completed all steps.")
              : (isGerman ? "Schließe alle Schritte ab." : "Complete all steps for optimal preparation.")}
          </div>
        </div>
        <span className="text-xl font-bold" style={{ color: "#4A9EF8" }}>
          {Math.round(progress * 100)}%
        </span>
      </div>
      <div className="progress-bar-track">
        <div className="progress-bar-fill" style={{ width: `${progress * 100}%` }} />
      </div>
      <div className="flex">
        <MilestoneChip done={selfDone} label={isGerman ? "Self-Assessment" : "Self-Assessment"} />
        <div className="flex-1" />
        <MilestoneChip done={linkDone} label={isGerman ? "5 Umfragen" : "5 Surveys"} />
        <div className="flex-1" />
        <MilestoneChip done={interviewDone} label={isGerman ? "3 Interviews" : "3 Interviews"} />
      </div>
    </div>
  );
}

function MilestoneChip({ done, label }: { done: boolean; label: string }) {
  return (
    <div className="flex items-center gap-1">
      <span className="text-xs">{done ? "✅" : "⭕"}</span>
      <span className="text-[10px] font-semibold"
        style={{ color: done ? "var(--app-primary)" : "var(--app-tertiary)" }}>{label}</span>
    </div>
  );
}

function StepCard({ number, done, locked, title, subtitle, children }: {
  number: number; done: boolean; locked: boolean; title: string; subtitle: string;
  children?: React.ReactNode;
}) {
  return (
    <div className="rounded-2xl p-4 space-y-3"
      style={{
        background: done ? "rgba(74,158,248,0.07)" : "var(--app-card)",
        border: `1px solid ${done ? "rgba(74,158,248,0.4)" : "var(--app-border)"}`,
      }}>
      <div className="flex items-start gap-3">
        <div className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0"
          style={{ background: done ? "#4A9EF8" : locked ? "var(--app-card)" : "rgba(74,158,248,0.2)", border: locked ? "1px solid var(--app-border)" : "none" }}>
          {done
            ? <span className="text-white font-bold">✓</span>
            : <span className="font-bold text-sm" style={{ color: locked ? "var(--app-tertiary)" : "#4A9EF8" }}>{number}</span>}
        </div>
        <div className="flex-1 pt-0.5">
          <div className="font-semibold text-sm" style={{ color: locked ? "var(--app-tertiary)" : "var(--app-primary)" }}>
            {title}
          </div>
          <div className="text-xs mt-0.5" style={{ color: locked ? "var(--app-tertiary)" : "var(--app-secondary)" }}>
            {subtitle}
          </div>
        </div>
      </div>
      {!locked && children && <div className="space-y-2">{children}</div>}
    </div>
  );
}

function ActionButton({ label, icon, onClick, disabled = false, gradient = false }: {
  label: string; icon: string; onClick: () => void; disabled?: boolean; gradient?: boolean;
}) {
  return (
    <button onClick={onClick} disabled={disabled}
      className={gradient ? "btn-gradient" : ""}
      style={gradient ? {} : {
        width: "100%", height: 46, borderRadius: 12, display: "flex",
        alignItems: "center", justifyContent: "center", gap: 8,
        fontWeight: 600, fontSize: "0.9rem",
        background: disabled ? "var(--app-input)" : "rgba(74,158,248,0.85)",
        color: disabled ? "var(--app-tertiary)" : "white",
        cursor: disabled ? "not-allowed" : "pointer",
      }}>
      <span>{icon}</span> {label}
    </button>
  );
}

function ShareIconButton({ label, icon, onClick }: { label: string; icon: string; onClick: () => void }) {
  return (
    <button onClick={onClick} className="flex-1 flex flex-col items-center gap-1">
      <div className="w-13 h-13 flex items-center justify-center rounded-xl text-xl"
        style={{ background: "var(--app-input)", border: "1px solid var(--app-border)", width: 52, height: 52 }}>
        {icon}
      </div>
      <span className="text-[10px]" style={{ color: "var(--app-tertiary)" }}>{label}</span>
    </button>
  );
}

function ResponseProgressBar({ responseCount, isGerman }: { responseCount: number; isGerman: boolean }) {
  const pct = Math.min(responseCount / TARGET_RESPONSES, 1);
  const milestoneX = (MIN_RESPONSES / TARGET_RESPONSES) * 100;
  return (
    <div className="space-y-1.5">
      <div className="relative h-2 rounded-full overflow-visible" style={{ background: "var(--app-input)" }}>
        <div className="absolute left-0 top-0 h-2 rounded-full transition-all duration-500"
          style={{ width: `${pct * 100}%`, background: "#4A9EF8" }} />
        <div className="absolute top-[-3px] w-0.5 h-4 rounded"
          style={{ left: `${milestoneX}%`, background: "var(--app-card)" }} />
      </div>
      <div className="flex justify-between text-[10px]" style={{ color: "var(--app-tertiary)" }}>
        <span>0</span>
        <span style={{ color: responseCount >= 5 ? "#4A9EF8" : undefined }}>
          {isGerman ? "5 min" : "5 min"}
          {responseCount >= 5 && responseCount < 12 && <> ✓</>}
        </span>
        <span style={{ color: responseCount >= 12 ? "#4A9EF8" : undefined }}>
          {isGerman ? "12 ideal" : "12 ideal"}
        </span>
      </div>
    </div>
  );
}
