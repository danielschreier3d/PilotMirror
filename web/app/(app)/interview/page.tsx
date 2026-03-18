"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { supabase, HINT_URL, SUPABASE_ANON } from "@/lib/supabase";
import {
  buildSession, totalCount, CATEGORY_META, SESSION_SIZE_META,
  type SessionSize, type IQuestion,
} from "@/lib/interview-questions";

type Phase = "setup" | "interview" | "done";
function t(de: string, en: string, g: boolean) { return g ? de : en; }

// ─── SVG Icons ─────────────────────────────────────────────────────────────────

function PersonGroupSVG() {
  return (
    <svg width="60" height="50" viewBox="0 0 60 50" fill="#4A9EF8">
      <circle cx="22" cy="14" r="10" />
      <path d="M2 46c0-11 9-16 20-16s20 5 20 16H2z" />
      <circle cx="42" cy="12" r="9" />
      <path d="M32 46c0-9.5 7.5-14 18-14S58 36.5 58 46H32z" />
    </svg>
  );
}

function SparklesSVG({ size = 14, color = "#FF9F0A" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <path d="M12 2l1.5 4.5L18 8l-4.5 1.5L12 14l-1.5-4.5L6 8l4.5-1.5L12 2zM5 17l.75 2.25L8 20l-2.25.75L5 22l-.75-2.25L2 20l2.25-.75L5 17zM20 17l.75 2.25L23 20l-2.25.75L20 22l-.75-2.25L17 20l2.25-.75L20 17z"/>
    </svg>
  );
}

function CircleCheckSVG({ selected }: { selected: boolean }) {
  if (selected) {
    return (
      <svg width="22" height="22" viewBox="0 0 24 24">
        <circle cx="12" cy="12" r="12" fill="#4A9EF8" />
        <path d="M7.5 12.5l3 3 6-6" stroke="white" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      </svg>
    );
  }
  return (
    <svg width="22" height="22" viewBox="0 0 24 24">
      <circle cx="12" cy="12" r="10.5" fill="none" stroke="var(--app-tertiary)" strokeWidth="1.5" />
    </svg>
  );
}

function CategoryIconSVG({ category, size = 13, color = "#4A9EF8" }: { category: string; size?: number; color?: string }) {
  const p = { width: size, height: size, viewBox: "0 0 24 24", fill: color };
  switch (category) {
    case "math":
      return <svg {...p} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round"><path d="M4 6h16M4 12h16M4 18h10"/><path d="M17 15l3 3-3 3"/></svg>;
    case "physics":
      return <svg {...p} fill="none" stroke={color} strokeWidth="1.5"><circle cx="12" cy="12" r="2.5" fill={color}/><ellipse cx="12" cy="12" rx="9" ry="3.5"/><ellipse cx="12" cy="12" rx="9" ry="3.5" transform="rotate(60 12 12)"/><ellipse cx="12" cy="12" rx="9" ry="3.5" transform="rotate(-60 12 12)"/></svg>;
    case "navigation":
      return <svg {...p}><path d="M12 2a10 10 0 100 20A10 10 0 0012 2zm3.5 6.5l-5 10-2-4-4-2 10-5z"/></svg>;
    case "aviation":
      return <svg {...p}><path d="M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z"/></svg>;
    case "english":
      return <svg {...p} fill="none" stroke={color} strokeWidth="1.5"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 010 20M12 2a15.3 15.3 0 000 20"/></svg>;
    case "spatial":
      return <svg {...p} fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round"><path d="M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z"/><path d="M3.27 6.96L12 12.01l8.73-5.05M12 22.08V12"/></svg>;
    case "personality":
      return <svg {...p}><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg>;
    case "judgment":
      return <svg {...p}><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/></svg>;
    case "school":
      return <svg {...p}><path d="M12 3L1 9l4 2.18V17.5c0 .63.37 1.21.94 1.48L12 21l6.06-2.02c.57-.27.94-.85.94-1.48V11.18L21 10v6h2V9L12 3zm6.82 6L12 12.72 5.18 9 12 5.28 18.82 9zM18 17.44l-6 2-6-2v-4.87l6 3.27 6-3.27v4.87z"/></svg>;
    default:
      return <SparklesSVG size={size} color={color} />;
  }
}

function CheckmarkCircleSVG({ size = 20, color = "#34C759" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
    </svg>
  );
}

function ChevronSVG({ dir = "right", size = 16, color = "currentColor" }: { dir?: "left"|"right"|"down"|"up"; size?: number; color?: string }) {
  const d = { right: "M9 18l6-6-6-6", left: "M15 18l-6-6 6-6", down: "M6 9l6 6 6-6", up: "M18 15l-6-6-6 6" }[dir];
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.5" strokeLinecap="round"><path d={d}/></svg>;
}

// ─── Page ──────────────────────────────────────────────────────────────────────

export default function InterviewPage() {
  const { user, isGerman } = useAuth();
  const router = useRouter();

  const [phase, setPhase]             = useState<Phase>("setup");
  const [aiQStrings, setAIQStrings]   = useState<string[]>([]);
  const [isAIQ, setIsAIQ]             = useState(false);
  const [sessionSize, setSize]        = useState<SessionSize>("medium");
  const [sessionQ, setSessionQ]       = useState<IQuestion[]>([]);
  const [idx, setIdx]                 = useState(0);
  const [hint, setHint]               = useState<string | null>(null);
  const [showHint, setShowHint]       = useState(false);
  const [loadingHint, setLoadingHint] = useState(false);
  const [showFollowUps, setFollowUps] = useState(false);
  const [runs, setRuns]               = useState(0);
  const [showEndAlert, setEndAlert]   = useState(false);

  useEffect(() => {
    setRuns(parseInt(localStorage.getItem("pm_interview_run_count") ?? "0", 10));
    const aiQ = localStorage.getItem("pm_interview_questions_v1");
    if (aiQ) {
      try {
        const parsed = JSON.parse(aiQ);
        if (Array.isArray(parsed) && parsed.length > 0) {
          setAIQStrings(parsed); setIsAIQ(true); return;
        }
      } catch { /* */ }
    }
    setIsAIQ(false);
  }, []);

  function aiQuestionObjects(): IQuestion[] {
    return aiQStrings.map((q, i) => ({
      id: `ai_${i}`, category: "personality" as const,
      de: q, en: q, isAIGenerated: true,
    }));
  }

  function startInterview() {
    const qs = buildSession(
      sessionSize, runs,
      user?.flightLicenses ?? [],
      user?.assessmentType,
      aiQuestionObjects()
    );
    setSessionQ(qs); setIdx(0);
    setHint(null); setShowHint(false); setFollowUps(false);
    setPhase("interview");
  }

  function prevQ() {
    if (idx > 0) { setHint(null); setShowHint(false); setFollowUps(false); setIdx(idx - 1); }
  }
  function nextQ() {
    setHint(null); setShowHint(false); setFollowUps(false);
    if (idx < sessionQ.length - 1) { setIdx(idx + 1); } else { finish(); }
  }

  async function finish() {
    const n = runs + 1;
    localStorage.setItem("pm_interview_run_count", String(n));
    setRuns(n); setPhase("done");
    if (user) await supabase.from("users").update({ interview_run_count: n }).eq("id", user.id);
  }

  async function toggleHint() {
    if (hint !== null) { setShowHint(!showHint); return; }
    if (loadingHint) return;
    const q = sessionQ[idx]; if (!q) return;
    setLoadingHint(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const res = await fetch(HINT_URL, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${session?.access_token ?? SUPABASE_ANON}`,
          "apikey": SUPABASE_ANON, "Content-Type": "application/json",
        },
        body: JSON.stringify({ question: isGerman ? q.de : q.en, language: isGerman ? "de" : "en" }),
      });
      const json = await res.json();
      setHint(json.hint ?? ""); setShowHint(true);
    } catch { /* */ } finally { setLoadingHint(false); }
  }

  // ── Setup ─────────────────────────────────────────────────────────────────
  if (phase === "setup") {
    const pool = (runs % 3) + 1;
    const runLabel = runs === 0
      ? t("Erster Durchgang", "First run", isGerman)
      : t(`Durchgang ${runs + 1} · Pool ${pool}/3`, `Run ${runs + 1} · Pool ${pool}/3`, isGerman);

    return (
      <div className="min-h-svh flex flex-col" style={{ background: "var(--app-bg)" }}>
        {/* Nav */}
        <div className="flex items-center px-4"
          style={{ paddingTop: "max(env(safe-area-inset-top,12px),12px)", paddingBottom: 12 }}>
          <button onClick={() => router.back()}
            className="flex items-center gap-0.5 text-sm font-semibold ios-press"
            style={{ color: "#4A9EF8" }}>
            <ChevronSVG dir="left" size={18} color="#4A9EF8" />
            {t("Zurück","Back",isGerman)}
          </button>
          <h1 className="flex-1 text-center font-semibold text-base" style={{ color: "var(--app-primary)" }}>
            Interview Simulation
          </h1>
          <div style={{ minWidth: 60 }} />
        </div>

        <div className="flex-1 overflow-y-auto">
          {/* Header */}
          <div className="flex flex-col items-center px-6 pt-6 pb-5 space-y-3">
            <PersonGroupSVG />
            <h2 className="text-2xl font-bold text-center" style={{ color: "var(--app-primary)" }}>
              Interview Simulation
            </h2>
            <p className="text-sm text-center" style={{ color: "var(--app-secondary)" }}>
              {t("Wähle den Umfang der Session aus.","Choose the session size.",isGerman)}
            </p>
            {/* Info box */}
            <div className="w-full rounded-2xl p-4 flex items-start gap-3"
              style={{ background: "rgba(74,158,248,0.1)", border: "1px solid rgba(74,158,248,0.25)" }}>
              <svg className="flex-shrink-0 mt-0.5" width="16" height="16" viewBox="0 0 24 24" fill="#4A9EF8">
                <path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-2 12H6v-2h12v2zm0-3H6V9h12v2zm0-3H6V6h12v2z"/>
              </svg>
              <p className="text-sm leading-snug" style={{ color: "var(--app-primary)" }}>
                {t(
                  "Such dir jemanden, der dich in einer simulierten Interviewsituation mit den Fragen unseres Simulators interviewt — so nah an der Realität wie möglich.",
                  "Find someone to interview you in a simulated interview situation using our simulator's questions — as close to the real thing as possible.",
                  isGerman
                )}
              </p>
            </div>
            {/* Assessment badge */}
            {user?.assessmentType && (
              <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-semibold"
                style={{ background: "rgba(74,158,248,0.12)", color: "#4A9EF8" }}>
                <CategoryIconSVG category="aviation" size={13} color="#4A9EF8" />
                {user.assessmentType}
              </div>
            )}
          </div>

          {/* Size cards */}
          <div className="grid grid-cols-3 gap-3 px-5 mb-4">
            {(["small","medium","large"] as SessionSize[]).map(key => {
              const sz  = SESSION_SIZE_META[key];
              const cnt = totalCount(key, isAIQ);
              const sel = sessionSize === key;
              const aiN = key === "small" ? 2 : key === "medium" ? 3 : 4;
              return (
                <button key={key} onClick={() => setSize(key)}
                  className="flex flex-col items-center py-5 px-2 rounded-2xl ios-press"
                  style={{
                    background: sel ? "var(--app-card)" : "transparent",
                    border: `${sel ? 2 : 1}px solid ${sel ? "#4A9EF8" : "var(--app-border)"}`,
                    gap: 5, justifyContent: "center",
                  }}>
                  <span className="font-bold" style={{ fontSize: 26, color: sel ? "#4A9EF8" : "var(--app-primary)", lineHeight: 1 }}>
                    {cnt}
                  </span>
                  <span className="font-semibold text-sm" style={{ color: "var(--app-primary)" }}>
                    {isGerman ? sz.de : sz.en}
                  </span>
                  <span className="text-xs text-center" style={{ color: "var(--app-secondary)", lineHeight: 1.3, whiteSpace: "pre-line" }}>
                    {isGerman ? sz.descDE : sz.descEN}
                  </span>
                  {isAIQ && (
                    <span className="flex items-center gap-0.5 text-xs font-bold" style={{ color: "#FF9F0A" }}>
                      <SparklesSVG size={10} /> +{aiN} KI
                    </span>
                  )}
                  <CircleCheckSVG selected={sel} />
                </button>
              );
            })}
          </div>

          {/* AI info / no-AI hint */}
          {isAIQ ? (
            <div className="flex items-center justify-center gap-1.5 mb-2 px-5">
              <SparklesSVG />
              <span className="text-sm font-semibold" style={{ color: "#FF9F0A" }}>
                {t(
                  `${sessionSize === "small" ? 2 : sessionSize === "medium" ? 3 : 4} KI-Fragen aus deinem Profil enthalten`,
                  `${sessionSize === "small" ? 2 : sessionSize === "medium" ? 3 : 4} AI questions from your profile included`,
                  isGerman
                )}
              </span>
            </div>
          ) : (
            <div className="mx-5 p-3 rounded-xl flex items-start gap-2 mb-2"
              style={{ background: "var(--app-card)", border: "1px solid var(--app-border)" }}>
              <svg className="flex-shrink-0 mt-0.5" width="13" height="13" viewBox="0 0 24 24" fill="var(--app-tertiary)">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/>
              </svg>
              <p className="text-xs leading-snug" style={{ color: "var(--app-secondary)" }}>
                {t(
                  "Führe zuerst die KI-Analyse durch — danach werden personalisierte KI-Fragen aus deinem Profil ergänzt.",
                  "Run the AI analysis first — personalised questions from your profile will then be added.",
                  isGerman
                )}
              </p>
            </div>
          )}

          {/* Run counter */}
          <div className="flex items-center justify-center gap-1.5 pb-6">
            {runs >= 3
              ? <CheckmarkCircleSVG size={16} color="#34C759" />
              : <svg width="16" height="16" viewBox="0 0 24 24" fill="var(--app-secondary)"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>}
            <span className="text-sm font-semibold" style={{ color: runs >= 3 ? "#34C759" : "var(--app-secondary)" }}>
              {runLabel}
            </span>
          </div>
        </div>

        <div className="px-5 pb-safe">
          <button onClick={startInterview} className="btn-primary">
            {t("Starten","Start",isGerman)}
          </button>
        </div>
      </div>
    );
  }

  // ── Interview ──────────────────────────────────────────────────────────────
  if (phase === "interview") {
    const total    = sessionQ.length;
    const q        = sessionQ[idx];
    if (!q) return null;
    const isLast   = idx === total - 1;
    const meta     = CATEGORY_META[q.category];
    const catLabel = isGerman ? meta.de : meta.en;
    const qText    = isGerman ? q.de : q.en;
    const ansText  = isGerman ? q.answerDE : q.answerEN;
    const followUps = isGerman ? q.followUpsDE : q.followUpsEN;
    const hintVisible = hint !== null && showHint;

    return (
      <div className="min-h-svh flex flex-col" style={{ background: "var(--app-bg)" }}>
        {/* Progress */}
        <div className="px-5" style={{ paddingTop: "max(env(safe-area-inset-top,16px),16px)" }}>
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-semibold" style={{ color: "var(--app-secondary)" }}>
              {idx + 1} / {total}
            </span>
            <button onClick={() => setEndAlert(true)}
              className="text-sm font-semibold ios-press" style={{ color: "#4A9EF8" }}>
              {t("Beenden","End",isGerman)}
            </button>
          </div>
          <div className="progress-bar-track">
            <div className="progress-bar-fill" style={{ width: `${((idx + 1) / total) * 100}%` }} />
          </div>
        </div>

        {/* Scrollable content */}
        <div className="flex-1 overflow-y-auto px-6 py-6 flex flex-col items-center" style={{ gap: 18 }}>

          {/* Category chip + optional AI badge */}
          <div className="flex items-center gap-2 flex-wrap justify-center">
            <div className="flex items-center gap-1.5 px-4 py-2 rounded-full"
              style={{ background: "rgba(74,158,248,0.15)", border: "1px solid rgba(74,158,248,0.3)" }}>
              <CategoryIconSVG category={q.category} size={13} color="#4A9EF8" />
              <span className="text-sm font-semibold" style={{ color: "#4A9EF8" }}>{catLabel}</span>
            </div>
            {q.isAIGenerated && (
              <div className="flex items-center gap-1 px-2.5 py-1.5 rounded-full"
                style={{ background: "rgba(255,159,10,0.15)", border: "1px solid rgba(255,159,10,0.3)" }}>
                <SparklesSVG size={11} />
                <span className="text-xs font-semibold" style={{ color: "#FF9F0A" }}>
                  {t("KI-Frage","AI Question",isGerman)}
                </span>
              </div>
            )}
          </div>

          {/* Question */}
          <p className="text-xl font-semibold text-center leading-snug"
            style={{ color: "var(--app-primary)", paddingLeft: 4, paddingRight: 4 }}>
            {qText}
          </p>

          {/* Answer card (math / english / spatial) */}
          {meta.showsAnswer && ansText && (
            <div className="w-full rounded-2xl p-4 flex items-start gap-3"
              style={{ background: "rgba(52,199,89,0.12)", border: "1.5px solid rgba(52,199,89,0.35)" }}>
              <span className="flex-shrink-0 mt-0.5"><CheckmarkCircleSVG size={20} color="#34C759" /></span>
              <div>
                <p className="text-xs font-bold mb-1" style={{ color: "rgba(52,199,89,0.8)" }}>
                  {t("Antwort","Answer",isGerman)}
                </p>
                <p className="font-semibold text-base" style={{ color: "var(--app-primary)" }}>{ansText}</p>
              </div>
            </div>
          )}

          {/* AI hint toggle (only for supportsAIHint && !showsAnswer) */}
          {meta.supportsAIHint && !meta.showsAnswer && (
            <>
              <button onClick={toggleHint} disabled={loadingHint}
                className="flex items-center gap-1.5 px-4 py-2.5 rounded-full ios-press"
                style={{
                  background: "rgba(255,159,10,0.12)",
                  border: "1px solid rgba(255,159,10,0.3)",
                  opacity: loadingHint ? 0.7 : 1,
                }}>
                {loadingHint
                  ? <div className="spinner" style={{ width: 13, height: 13, borderColor: "rgba(255,159,10,0.3)", borderTopColor: "#FF9F0A" }} />
                  : <SparklesSVG size={13} />}
                <span className="text-sm font-semibold" style={{ color: "#FF9F0A" }}>
                  {hintVisible
                    ? t("KI-Antwort ausblenden","Hide AI answer",isGerman)
                    : t("KI-Musterantwort anzeigen","Show AI model answer",isGerman)}
                </span>
              </button>
              {hintVisible && (
                <div className="w-full rounded-2xl p-4 flex items-start gap-3"
                  style={{ background: "rgba(255,159,10,0.08)", border: "1px solid rgba(255,159,10,0.3)" }}>
                  <span className="flex-shrink-0 mt-0.5"><SparklesSVG size={14} /></span>
                  <p className="text-sm leading-relaxed" style={{ color: "var(--app-primary)" }}>{hint}</p>
                </div>
              )}
            </>
          )}

          {/* Follow-ups (collapsible) */}
          {followUps && followUps.length > 0 && (
            <div className="w-full rounded-2xl overflow-hidden"
              style={{ background: "rgba(74,158,248,0.07)", border: "1px solid rgba(74,158,248,0.22)" }}>
              <button onClick={() => setFollowUps(!showFollowUps)}
                className="w-full flex items-center justify-between px-4 py-3.5 ios-press">
                <div className="flex items-center gap-2">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#4A9EF8" strokeWidth="2" strokeLinecap="round"><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
                  <span className="text-sm font-semibold" style={{ color: "#4A9EF8" }}>
                    {t(`Nachfragen (${followUps.length})`,`Follow-ups (${followUps.length})`,isGerman)}
                  </span>
                </div>
                <ChevronSVG dir={showFollowUps ? "up" : "down"} size={14} color="#4A9EF8" />
              </button>
              {showFollowUps && (
                <div className="px-4 pb-4 space-y-3">
                  {followUps.map((f, i) => (
                    <div key={i} className="flex items-start gap-2">
                      <svg className="flex-shrink-0 mt-0.5" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="var(--app-tertiary)" strokeWidth="2" strokeLinecap="round"><path d="M9 18l6-6M15 6l-6 6"/></svg>
                      <p className="text-sm" style={{ color: "var(--app-primary)" }}>{f}</p>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        {/* Bottom nav */}
        <div className="px-5 pb-safe flex gap-3">
          <button onClick={prevQ} disabled={idx === 0}
            className="flex-1 h-14 rounded-2xl flex items-center justify-center gap-1.5 font-semibold ios-press"
            style={{
              background: idx > 0 ? "var(--app-input)" : "rgba(128,128,128,0.08)",
              color: idx > 0 ? "var(--app-primary)" : "var(--app-tertiary)",
              border: "1px solid var(--app-border)",
            }}>
            <ChevronSVG dir="left" size={16} color={idx > 0 ? "var(--app-primary)" : "var(--app-tertiary)"} />
            {t("Zurück","Back",isGerman)}
          </button>
          <button onClick={nextQ}
            className="flex-1 h-14 rounded-2xl flex items-center justify-center gap-1.5 font-semibold ios-press"
            style={{ background: "#4A9EF8", color: "white" }}>
            {isLast ? t("Fertig","Done",isGerman) : t("Weiter","Next",isGerman)}
            {isLast
              ? <CheckmarkCircleSVG size={16} color="white" />
              : <ChevronSVG dir="right" size={16} color="white" />}
          </button>
        </div>

        {/* End alert overlay */}
        {showEndAlert && (
          <div className="fixed inset-0 flex items-center justify-center z-50"
            style={{ background: "rgba(0,0,0,0.5)" }}>
            <div className="card p-6 mx-8 space-y-4 card-in">
              <h3 className="font-bold text-center" style={{ color: "var(--app-primary)" }}>
                {t("Interview beenden?","End interview?",isGerman)}
              </h3>
              <p className="text-sm text-center" style={{ color: "var(--app-secondary)" }}>
                {t(`Du hast ${idx + 1} von ${total} Fragen gestellt.`,
                   `You have answered ${idx + 1} of ${total} questions.`,isGerman)}
              </p>
              <div className="flex gap-3">
                <button onClick={() => setEndAlert(false)}
                  className="flex-1 py-3 rounded-xl font-semibold text-sm ios-press"
                  style={{ background: "var(--app-input)", color: "var(--app-primary)" }}>
                  {t("Abbrechen","Cancel",isGerman)}
                </button>
                <button onClick={() => { setEndAlert(false); finish(); }}
                  className="flex-1 py-3 rounded-xl font-semibold text-sm ios-press"
                  style={{ background: "rgba(255,59,48,0.15)", color: "#FF3B30" }}>
                  {t("Beenden","End",isGerman)}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  // ── Done ──────────────────────────────────────────────────────────────────
  return (
    <div className="min-h-svh flex flex-col items-center justify-center px-5 space-y-5"
      style={{ background: "var(--app-bg)" }}>
      <CheckmarkCircleSVG size={64} color="#34C759" />
      <h2 className="text-2xl font-bold text-center" style={{ color: "var(--app-primary)" }}>
        {t("Interview abgeschlossen!","Interview complete!",isGerman)}
      </h2>
      <p className="text-sm text-center" style={{ color: "var(--app-secondary)" }}>
        {runs >= 3
          ? t("Mindestens 3 Durchgänge absolviert","At least 3 runs completed",isGerman)
          : t(`Durchgang ${runs} von 3`,`Run ${runs} of 3`,isGerman)}
      </p>
      <div className="flex gap-3 w-full max-w-xs pt-2">
        <button onClick={() => { setPhase("setup"); setHint(null); setShowHint(false); }}
          className="flex-1 py-3 rounded-xl font-semibold text-sm ios-press"
          style={{ background: "var(--app-input)", color: "var(--app-primary)" }}>
          {t("Neue Session","New Session",isGerman)}
        </button>
        <button onClick={() => router.back()}
          className="flex-1 py-3 rounded-xl font-semibold text-sm ios-press"
          style={{ background: "#4A9EF8", color: "white" }}>
          {t("Fertig","Done",isGerman)}
        </button>
      </div>
    </div>
  );
}
