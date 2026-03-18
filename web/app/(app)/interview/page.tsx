"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { supabase, HINT_URL, SUPABASE_ANON } from "@/lib/supabase";

type Phase = "setup" | "interview" | "done";
type SessionSize = "small" | "medium" | "large";

function t(de: string, en: string, g: boolean) { return g ? de : en; }

const SIZE_META: Record<SessionSize, { de: string; en: string; descDE: string; descEN: string; count: number }> = {
  small:  { de: "Klein",  en: "Small",  descDE: "1 Frage\npro Kategorie",  descEN: "1 question\nper category",  count: 3 },
  medium: { de: "Mittel", en: "Medium", descDE: "2 Fragen\npro Kategorie", descEN: "2 questions\nper category", count: 5 },
  large:  { de: "Groß",   en: "Large",  descDE: "3 Fragen\npro Kategorie", descEN: "3 questions\nper category", count: 0 },
};

const CAT_DE   = ["Entscheidungsfindung", "Umgang mit Kritik", "Stärken", "Teamarbeit", "Motivation"];
const CAT_EN   = ["Decision Making",      "Handling Criticism","Strengths","Teamwork",   "Motivation"];
const CAT_ICON = ["⚡", "💬", "⭐", "👥", "🎯"];

const GEN_Q_DE = [
  "Beschreibe eine Situation, in der du unter Zeitdruck eine wichtige Entscheidung treffen musstest. Was hast du getan und was hast du daraus gelernt?",
  "Wie gehst du mit Kritik um, besonders wenn du anderer Meinung bist als dein Vorgesetzter oder Prüfer?",
  "Was ist deine größte Stärke, und wie würde sich diese in einem realen Assessment-Center zeigen?",
  "Beschreibe eine Situation, in der ein Teamkollege oder Mitschüler Fehler gemacht hat. Wie hast du reagiert?",
  "Was motiviert dich, Pilot zu werden — und was ist deine größte Sorge in Bezug auf das Auswahlverfahren?",
];
const GEN_Q_EN = [
  "Describe a situation where you had to make an important decision under time pressure. What did you do and what did you learn?",
  "How do you handle criticism, especially when you disagree with your superior or examiner?",
  "What is your greatest strength, and how would it show in a real assessment centre?",
  "Describe a situation where a teammate or fellow student made mistakes. How did you react?",
  "What motivates you to become a pilot — and what is your biggest concern about the selection process?",
];

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

export default function InterviewPage() {
  const { user, isGerman } = useAuth();
  const router = useRouter();

  const [phase, setPhase]             = useState<Phase>("setup");
  const [allQuestions, setAllQ]       = useState<string[]>([]);
  const [isAIQ, setIsAIQ]             = useState(false);
  const [sessionSize, setSize]        = useState<SessionSize>("medium");
  const [sessionQ, setSessionQ]       = useState<string[]>([]);
  const [idx, setIdx]                 = useState(0);
  const [hint, setHint]               = useState<string | null>(null);
  const [showHint, setShowHint]       = useState(false);
  const [loadingHint, setLoadingHint] = useState(false);
  const [runs, setRuns]               = useState(0);
  const [showEndAlert, setEndAlert]   = useState(false);

  useEffect(() => {
    setRuns(parseInt(localStorage.getItem("pm_interview_run_count") ?? "0", 10));
    const aiQ = localStorage.getItem("pm_interview_questions_v1");
    if (aiQ) {
      try {
        const parsed = JSON.parse(aiQ);
        if (Array.isArray(parsed) && parsed.length > 0) {
          setAllQ(parsed); setIsAIQ(true); return;
        }
      } catch { /* */ }
    }
    setAllQ(isGerman ? GEN_Q_DE : GEN_Q_EN);
    setIsAIQ(false);
  }, [isGerman]);

  function sizeCount(s: SessionSize) {
    const base = SIZE_META[s].count || allQuestions.length;
    return Math.min(base, allQuestions.length);
  }

  function startInterview() {
    const qs = allQuestions.slice(0, sizeCount(sessionSize));
    setSessionQ(qs); setIdx(0); setHint(null); setShowHint(false); setPhase("interview");
  }

  function prevQ() { if (idx > 0) { setHint(null); setShowHint(false); setIdx(idx - 1); } }
  function nextQ() {
    setHint(null); setShowHint(false);
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
          "apikey": SUPABASE_ANON,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ question: q, language: isGerman ? "de" : "en" }),
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
            <span className="text-lg leading-none">‹</span>
            {t("Zurück","Back",isGerman)}
          </button>
          <h1 className="flex-1 text-center font-semibold text-base"
            style={{ color: "var(--app-primary)" }}>
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
              <span className="flex-shrink-0 text-base mt-0.5" style={{ color: "#4A9EF8" }}>🗣</span>
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
                ✈ {user.assessmentType}
              </div>
            )}
          </div>

          {/* Size cards */}
          <div className="grid grid-cols-3 gap-3 px-5 mb-4">
            {(["small","medium","large"] as SessionSize[]).map((key) => {
              const sz   = SIZE_META[key];
              const cnt  = sizeCount(key);
              const sel  = sessionSize === key;
              const aiN  = key === "small" ? 2 : key === "medium" ? 3 : 4;
              return (
                <button key={key} onClick={() => setSize(key)}
                  className="flex flex-col items-center py-5 px-2 rounded-2xl ios-press"
                  style={{
                    background: sel ? "var(--app-card)" : "transparent",
                    border: `${sel ? 2 : 1}px solid ${sel ? "#4A9EF8" : "var(--app-border)"}`,
                    gap: 5,
                    justifyContent: "center",
                  }}>
                  <span className="font-bold"
                    style={{ fontSize: 26, color: sel ? "#4A9EF8" : "var(--app-primary)", lineHeight: 1 }}>
                    ~{cnt}
                  </span>
                  <span className="font-semibold text-sm" style={{ color: "var(--app-primary)" }}>
                    {isGerman ? sz.de : sz.en}
                  </span>
                  <span className="text-xs text-center"
                    style={{ color: "var(--app-secondary)", lineHeight: 1.3, whiteSpace: "pre-line" }}>
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

          {/* AI info / generic hint */}
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
              <span className="text-xs flex-shrink-0 mt-0.5" style={{ color: "var(--app-tertiary)" }}>ℹ</span>
              <p className="text-xs leading-snug" style={{ color: "var(--app-secondary)" }}>
                {t(
                  "Fülle zuerst die Selbsteinschätzung aus — danach werden personalisierte KI-Fragen ergänzt.",
                  "Complete the self-assessment first — personalised AI questions will then be added.",
                  isGerman
                )}
              </p>
            </div>
          )}

          {/* Run counter */}
          <div className="flex items-center justify-center gap-1.5 pb-6">
            <span className="text-sm font-semibold"
              style={{ color: runs >= 3 ? "#34C759" : "var(--app-secondary)" }}>
              {runs >= 3
                ? <span style={{ color: "#34C759" }}>✓ {runLabel}</span>
                : <>{runs > 0 ? "✓" : "#"} {runLabel}</>}
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
    const total  = sessionQ.length;
    const q      = sessionQ[idx] ?? "";
    const isLast = idx === total - 1;
    const catLabel = (!isAIQ && CAT_DE[idx])
      ? (isGerman ? CAT_DE[idx] : CAT_EN[idx])
      : t("KI-Frage","AI Question",isGerman);
    const catIcon = !isAIQ ? (CAT_ICON[idx] ?? "💬") : null;
    const hintVisible = hint !== null && showHint;

    return (
      <div className="min-h-svh flex flex-col" style={{ background: "var(--app-bg)" }}>
        {/* Progress */}
        <div className="px-5"
          style={{ paddingTop: "max(env(safe-area-inset-top,16px),16px)", paddingBottom: 0 }}>
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

        {/* Content */}
        <div className="flex-1 overflow-y-auto px-6 py-6 flex flex-col items-center"
          style={{ gap: 20 }}>
          {/* Category chip */}
          <div className="flex items-center gap-1.5 px-4 py-2 rounded-full"
            style={{ background: "rgba(74,158,248,0.15)", border: "1px solid rgba(74,158,248,0.3)" }}>
            {catIcon
              ? <span style={{ fontSize: 13 }}>{catIcon}</span>
              : <SparklesSVG size={13} color="#4A9EF8" />}
            <span className="text-sm font-semibold" style={{ color: "#4A9EF8" }}>{catLabel}</span>
          </div>

          {/* Question */}
          <p className="text-xl font-semibold text-center leading-snug"
            style={{ color: "var(--app-primary)", paddingLeft: 4, paddingRight: 4 }}>
            {q}
          </p>

          {/* AI hint toggle */}
          <button onClick={toggleHint} disabled={loadingHint}
            className="flex items-center gap-1.5 px-4 py-2.5 rounded-full ios-press"
            style={{
              background: "rgba(255,159,10,0.12)",
              border: "1px solid rgba(255,159,10,0.3)",
              opacity: loadingHint ? 0.7 : 1,
            }}>
            {loadingHint
              ? <div className="spinner"
                  style={{ width: 13, height: 13, borderColor: "rgba(255,159,10,0.3)", borderTopColor: "#FF9F0A" }} />
              : <SparklesSVG size={13} />}
            <span className="text-sm font-semibold" style={{ color: "#FF9F0A" }}>
              {hintVisible
                ? t("KI-Antwort ausblenden","Hide AI answer",isGerman)
                : t("KI-Musterantwort anzeigen","Show AI model answer",isGerman)}
            </span>
          </button>

          {/* Hint card */}
          {hintVisible && (
            <div className="w-full rounded-2xl p-4 flex items-start gap-3"
              style={{ background: "rgba(255,159,10,0.08)", border: "1px solid rgba(255,159,10,0.3)" }}>
              <span className="flex-shrink-0 mt-0.5"><SparklesSVG size={14} /></span>
              <p className="text-sm leading-relaxed" style={{ color: "var(--app-primary)" }}>{hint}</p>
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
            <span className="text-base">‹</span> {t("Zurück","Back",isGerman)}
          </button>
          <button onClick={nextQ}
            className="flex-1 h-14 rounded-2xl flex items-center justify-center gap-1.5 font-semibold ios-press"
            style={{ background: "#4A9EF8", color: "white" }}>
            {isLast ? t("Fertig","Done",isGerman) : t("Weiter","Next",isGerman)}
            <span className="text-base">{isLast ? "✓" : "›"}</span>
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
                {t(
                  `Du hast ${idx + 1} von ${total} Fragen gestellt.`,
                  `You have answered ${idx + 1} of ${total} questions.`,
                  isGerman
                )}
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
      <svg width="64" height="64" viewBox="0 0 24 24" fill="#34C759">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
      </svg>
      <h2 className="text-2xl font-bold text-center" style={{ color: "var(--app-primary)" }}>
        {t("Interview abgeschlossen!","Interview complete!",isGerman)}
      </h2>
      <p className="text-sm text-center" style={{ color: "var(--app-secondary)" }}>
        {runs >= 3
          ? t("✓ Mindestens 3 Durchgänge absolviert","✓ At least 3 runs completed",isGerman)
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
