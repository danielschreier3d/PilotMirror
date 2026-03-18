"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { supabase } from "@/lib/supabase";
import { runAnalysis } from "@/lib/analysis";
import type { FeedbackLink, AnalysisResult } from "@/lib/types";
import { getFeedbackURL } from "@/lib/types";

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
  const [isRefreshing, setIsRefreshing]   = useState(false);

  // ── Load persisted data on mount ──────────────────────────────────────────
  useEffect(() => {
    setInterviewRuns(parseInt(localStorage.getItem("pm_interview_run_count") ?? "0", 10));
    const cached = localStorage.getItem("pm_analysis_result_v1");
    if (cached) { try { setAnalysisResult(JSON.parse(cached)); } catch { /* ignore */ } }
    const cachedLink = localStorage.getItem("pm_feedback_link");
    if (cachedLink) { try { setFeedbackLink(JSON.parse(cachedLink)); } catch { /* ignore */ } }
    const sr = localStorage.getItem("pm_self_responses");
    if (sr) { try { setSelfDone(Object.keys(JSON.parse(sr)).length >= 5); } catch { /* ignore */ } }
  }, []);

  // ── Load from Supabase ────────────────────────────────────────────────────
  const loadFromSupabase = useCallback(async () => {
    if (!user) return;
    setIsRefreshing(true);
    try {
      const { data: sessions } = await supabase
        .from("assessment_sessions").select("id").eq("candidate_id", user.id);
      if (!sessions || sessions.length === 0) { setIsRefreshing(false); return; }

      const sessionIds = sessions.map((s: { id: string }) => s.id);
      localStorage.setItem("pm_session_id", sessionIds[0]);

      const { count } = await supabase
        .from("self_responses").select("*", { count: "exact", head: true })
        .in("session_id", sessionIds);
      setSelfDone((count ?? 0) >= 5);

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

      const { data: userData } = await supabase
        .from("users").select("interview_run_count").eq("id", user.id).single();
      if (userData && userData.interview_run_count != null) {
        const runs = userData.interview_run_count as number;
        setInterviewRuns(runs);
        localStorage.setItem("pm_interview_run_count", String(runs));
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
      const { data: existingSessions } = await supabase
        .from("assessment_sessions").select("id").eq("candidate_id", user.id);
      if (existingSessions && existingSessions.length > 0) {
        const sessionIds = existingSessions.map((s: { id: string }) => s.id);
        const { data: existingLinks } = await supabase
          .from("feedback_links").select("*").in("session_id", sessionIds)
          .order("response_count", { ascending: false }).limit(1);
        if (existingLinks && existingLinks[0]) {
          const l = existingLinks[0];
          const fl: FeedbackLink = { id: l.id, sessionId: l.session_id, token: l.token, responseCount: l.response_count, createdAt: l.created_at };
          setFeedbackLink(fl);
          localStorage.setItem("pm_feedback_link", JSON.stringify(fl));
          return;
        }
      }
      let sessionId = localStorage.getItem("pm_session_id");
      if (!sessionId) {
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
      const fl: FeedbackLink = { id: linkId, sessionId: sessionId!, token, responseCount: 0, createdAt: new Date().toISOString() };
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

  function shareIMessage() {
    if (!feedbackLink) return;
    const url = getFeedbackURL(feedbackLink.token);
    const msg = isGerman
      ? `Hey! Kannst du mir kurz helfen? Ich bereite mich auf mein Pilotenauswahlverfahren vor:\n\n${url}`
      : `Hey! Could you help me? I'm preparing for my pilot assessment:\n\n${url}`;
    window.open(`sms:?body=${encodeURIComponent(msg)}`, "_blank");
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
      <div className="sticky top-0 z-40 px-4"
        style={{ background: "var(--app-bg)", borderBottom: "1px solid var(--app-border)", paddingBottom: 10, paddingTop: "max(env(safe-area-inset-top, 12px), 12px)" }}>
        <div className="flex items-center justify-between">
          <h1 className="text-xl font-bold" style={{ color: "var(--app-primary)" }}>Dashboard</h1>
          <button onClick={() => router.push("/profile")}
            className="w-9 h-9 flex items-center justify-center rounded-full"
            style={{ background: "var(--app-input)" }}>
            <PersonSVG size={18} color="var(--app-secondary)" />
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="px-4 py-4 space-y-4 pb-safe">

        {/* Header */}
        <div className="text-center space-y-2 pt-1">
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
          isGerman={isGerman} />

        {/* Step 1 */}
        <StepCard number={1} done={selfDone} locked={false}
          title={t("Self-Assessment ausfüllen","Complete Self-Assessment",isGerman)}
          subtitle={selfDone
            ? t("Abgeschlossen","Completed",isGerman)
            : t("Beantworte denselben Fragebogen über dich selbst","Answer the same questionnaire about yourself",isGerman)}>
          {!selfDone && (
            <ActionButton label={t("Jetzt starten","Start now",isGerman)}
              icon={<ClipboardSVG size={18} />}
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
              <div className="flex items-center gap-2 px-3 py-2.5 rounded-2xl"
                style={{ background: "var(--app-input)", border: "1px solid var(--app-border)" }}>
                <span className="text-xs font-mono truncate flex-1" style={{ color: "#4A9EF8", fontSize: "0.7rem" }}>
                  {getFeedbackURL(feedbackLink.token)}
                </span>
                <button onClick={copyLink} className="flex-shrink-0 p-1">
                  {copied
                    ? <CheckSVG size={16} color="#34C759" strokeWidth={2.5} />
                    : <CopySVG size={16} />}
                </button>
              </div>
              {/* Share buttons */}
              <div className="flex gap-2.5">
                <ShareIconButton label="WhatsApp" color="#25D366"
                  icon={<WhatsAppSVG />} onClick={shareWhatsApp} />
                <ShareIconButton label="iMessage" color="#34C759"
                  icon={<MessageSVG />} onClick={shareIMessage} />
                <ShareIconButton label="E-Mail" color="#4A9EF8"
                  icon={<MailSVG />} onClick={shareMail} />
                {typeof navigator !== "undefined" && "share" in navigator && (
                  <ShareIconButton label={t("Mehr","More",isGerman)} color="var(--app-input)"
                    icon={<ShareSVG />} onClick={shareNative} />
                )}
              </div>
            </div>
          ) : (
            <div className="space-y-2">
              <ActionButton
                label={isCreatingLink ? t("Wird erstellt…","Creating…",isGerman) : t("Link erstellen","Create link",isGerman)}
                icon={<LinkSVG size={18} />}
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
              icon={isAnalyzing ? <SpinnerSVG size={18} /> : <SparkSVG size={18} />}
              gradient disabled={isAnalyzing}
              onClick={triggerAnalysis} />
          )}
          {analysisResult?.personalitySummary && (
            <ActionButton label={t("Report anzeigen","View report",isGerman)}
              icon={<DocSVG size={18} />}
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
            icon={<PeopleSVG size={18} />}
            onClick={() => router.push("/interview")} />
          {interviewRuns > 0 && (
            <div className="flex items-center gap-2 mt-1 px-1">
              {[0,1,2].map((i) => (
                <div key={i} className="w-2.5 h-2.5 rounded-full"
                  style={{ background: i < interviewRuns ? "#4A9EF8" : "var(--app-border)" }} />
              ))}
              <span className="text-xs ml-0.5" style={{ color: interviewDone ? "#34C759" : "var(--app-secondary)" }}>
                {Math.min(interviewRuns,3)}/3 {isGerman ? "Durchgänge" : "runs"}
              </span>
            </div>
          )}
        </StepCard>

        <div className="h-4" />
      </div>
    </div>
  );
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function PrepCard({ progress, selfDone, linkDone, interviewDone, isFullyPrepared, isGerman }: {
  progress: number; selfDone: boolean; linkDone: boolean; interviewDone: boolean;
  isFullyPrepared: boolean; isGerman: boolean;
}) {
  return (
    <div className="rounded-2xl p-4 space-y-3"
      style={{
        background: "var(--app-card)",
        border: `1px solid ${isFullyPrepared ? "rgba(74,158,248,0.4)" : "var(--app-border)"}`,
      }}>
      <div className="flex items-center justify-between">
        <div className="flex-1 pr-4">
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
        <span className="text-xl font-bold flex-shrink-0" style={{ color: "#4A9EF8" }}>
          {Math.round(progress * 100)}%
        </span>
      </div>
      <div className="progress-bar-track">
        <div className="progress-bar-fill" style={{ width: `${progress * 100}%` }} />
      </div>
      <div className="flex items-center justify-between px-0.5">
        <MilestoneChip done={selfDone} label={isGerman ? "Self-Assessment" : "Self-Assessment"} />
        <MilestoneChip done={linkDone} label={isGerman ? "5 Umfragen" : "5 Surveys"} />
        <MilestoneChip done={interviewDone} label={isGerman ? "3 Interviews" : "3 Interviews"} />
      </div>
    </div>
  );
}

function MilestoneChip({ done, label }: { done: boolean; label: string }) {
  return (
    <div className="flex items-center gap-1.5">
      <div className="rounded-full flex items-center justify-center flex-shrink-0"
        style={{
          width: 16, height: 16,
          background: done ? "#4A9EF8" : "transparent",
          border: done ? "none" : "1.5px solid var(--app-border)",
        }}>
        {done && <CheckSVG size={9} color="white" strokeWidth={3} />}
      </div>
      <span className="text-[10px] font-semibold"
        style={{ color: done ? "var(--app-primary)" : "var(--app-tertiary)" }}>
        {label}
      </span>
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
        border: `1px solid ${done ? "rgba(74,158,248,0.35)" : "var(--app-border)"}`,
      }}>
      <div className="flex items-start gap-3">
        {/* Step circle */}
        <div className="rounded-full flex items-center justify-center flex-shrink-0"
          style={{
            width: 52, height: 52,
            background: done
              ? "#4A9EF8"
              : locked
                ? "var(--app-input)"
                : "rgba(74,158,248,0.15)",
            border: locked && !done ? "1.5px solid var(--app-border)" : done ? "none" : "1.5px solid rgba(74,158,248,0.35)",
          }}>
          {done
            ? <CheckSVG size={22} color="white" strokeWidth={2.5} />
            : <span className="font-bold text-base"
                style={{ color: locked ? "var(--app-tertiary)" : "#4A9EF8" }}>
                {number}
              </span>}
        </div>
        <div className="flex-1 pt-2">
          <div className="font-semibold text-sm leading-tight"
            style={{ color: locked ? "var(--app-tertiary)" : "var(--app-primary)" }}>
            {title}
          </div>
          <div className="text-xs mt-1 leading-snug"
            style={{ color: locked ? "var(--app-tertiary)" : "var(--app-secondary)" }}>
            {subtitle}
          </div>
        </div>
      </div>
      {!locked && children && <div className="space-y-2">{children}</div>}
    </div>
  );
}

function ActionButton({ label, icon, onClick, disabled = false, gradient = false }: {
  label: string; icon?: React.ReactNode; onClick: () => void; disabled?: boolean; gradient?: boolean;
}) {
  return (
    <button onClick={onClick} disabled={disabled}
      className={gradient ? "btn-gradient" : ""}
      style={gradient ? {} : {
        width: "100%", height: 50, borderRadius: 14, display: "flex",
        alignItems: "center", justifyContent: "center", gap: 8,
        fontWeight: 600, fontSize: "0.9rem",
        background: disabled ? "var(--app-input)" : "#4A9EF8",
        color: disabled ? "var(--app-tertiary)" : "white",
        cursor: disabled ? "not-allowed" : "pointer",
        transition: "opacity 0.15s",
      }}>
      {icon}
      <span>{label}</span>
    </button>
  );
}

function ShareIconButton({ label, icon, color, onClick }: {
  label: string; icon: React.ReactNode; color: string; onClick: () => void;
}) {
  return (
    <button onClick={onClick} className="flex-1 flex flex-col items-center gap-1.5">
      <div className="flex items-center justify-center rounded-2xl"
        style={{ width: 52, height: 52, background: color }}>
        {icon}
      </div>
      <span className="text-[10px] font-medium" style={{ color: "var(--app-secondary)" }}>
        {label}
      </span>
    </button>
  );
}

function ResponseProgressBar({ responseCount, isGerman }: { responseCount: number; isGerman: boolean }) {
  const pct = Math.min(responseCount / TARGET_RESPONSES, 1);
  const milestoneX = (MIN_RESPONSES / TARGET_RESPONSES) * 100;
  const unlockedLabel = isGerman
    ? (responseCount >= MIN_RESPONSES ? "5 min ✓ freigeschaltet" : "5 min")
    : (responseCount >= MIN_RESPONSES ? "5 min ✓ unlocked" : "5 min");
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
        <span style={{ color: responseCount >= MIN_RESPONSES ? "#4A9EF8" : undefined }}>
          {unlockedLabel}
        </span>
        <span style={{ color: responseCount >= TARGET_RESPONSES ? "#4A9EF8" : undefined }}>
          {isGerman ? "12 ideal" : "12 ideal"}
        </span>
      </div>
    </div>
  );
}

// ─── SVG Icon components ──────────────────────────────────────────────────────

function CheckSVG({ size = 16, color = "white", strokeWidth = 2.5 }: { size?: number; color?: string; strokeWidth?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  );
}

function CopySVG({ size = 16, color = "#4A9EF8" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
      <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/>
    </svg>
  );
}

function DocSVG({ size = 18, color = "white" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
      <polyline points="14 2 14 8 20 8"/>
      <line x1="16" y1="13" x2="8" y2="13"/>
      <line x1="16" y1="17" x2="8" y2="17"/>
    </svg>
  );
}

function PeopleSVG({ size = 18, color = "white" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
      <circle cx="9" cy="7" r="4"/>
      <path d="M23 21v-2a4 4 0 00-3-3.87"/>
      <path d="M16 3.13a4 4 0 010 7.75"/>
    </svg>
  );
}

function PersonSVG({ size = 18, color = "white" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/>
      <circle cx="12" cy="7" r="4"/>
    </svg>
  );
}

function SparkSVG({ size = 18, color = "white" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
    </svg>
  );
}

function SpinnerSVG({ size = 18, color = "white" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
      style={{ animation: "spin 1s linear infinite" }}>
      <path d="M21 12a9 9 0 11-6.219-8.56"/>
    </svg>
  );
}

function LinkSVG({ size = 18, color = "white" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M10 13a5 5 0 007.54.54l3-3a5 5 0 00-7.07-7.07l-1.72 1.71"/>
      <path d="M14 11a5 5 0 00-7.54-.54l-3 3a5 5 0 007.07 7.07l1.71-1.71"/>
    </svg>
  );
}

function ClipboardSVG({ size = 18, color = "white" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M16 4h2a2 2 0 012 2v14a2 2 0 01-2 2H6a2 2 0 01-2-2V6a2 2 0 012-2h2"/>
      <rect x="8" y="2" width="8" height="4" rx="1" ry="1"/>
    </svg>
  );
}

// Share icon SVGs
function WhatsAppSVG() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="white">
      <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
    </svg>
  );
}

function MessageSVG() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="white">
      <path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/>
    </svg>
  );
}

function MailSVG() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="white"
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
      <polyline points="22,6 12,13 2,6"/>
    </svg>
  );
}

function ShareSVG() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white"
      strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 12v8a2 2 0 002 2h12a2 2 0 002-2v-8"/>
      <polyline points="16 6 12 2 8 6"/>
      <line x1="12" y1="2" x2="12" y2="15"/>
    </svg>
  );
}
