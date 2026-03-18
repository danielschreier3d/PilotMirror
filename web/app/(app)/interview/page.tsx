"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { supabase, HINT_URL, SUPABASE_ANON } from "@/lib/supabase";
import type { AnalysisResult } from "@/lib/types";

type Phase = "setup" | "interview" | "done";

function t(de: string, en: string, g: boolean) { return g ? de : en; }

type SessionSize = "short" | "medium" | "long";
const SESSION_SIZES: Record<SessionSize, { de: string; en: string; detail: string; detailEN: string; count: number }> = {
  short:  { de: "Kurz",   en: "Short",  detail: "3 Fragen",    detailEN: "3 questions",   count: 3 },
  medium: { de: "Mittel", en: "Medium", detail: "5 Fragen",    detailEN: "5 questions",   count: 5 },
  long:   { de: "Lang",   en: "Long",   detail: "Alle Fragen", detailEN: "All questions", count: 0 },
};

const GENERIC_CATEGORIES_DE = ["Entscheidungsfindung", "Umgang mit Kritik", "Stärken", "Teamarbeit", "Motivation"];
const GENERIC_CATEGORIES_EN = ["Decision Making", "Handling Criticism", "Strengths", "Teamwork", "Motivation"];

// Generic interview questions (fallback)
const GENERIC_QUESTIONS_DE = [
  "Beschreibe eine Situation, in der du unter Zeitdruck eine wichtige Entscheidung treffen musstest. Was hast du getan und was hast du daraus gelernt?",
  "Wie gehst du mit Kritik um, besonders wenn du anderer Meinung bist als dein Vorgesetzter oder Prüfer?",
  "Was ist deine größte Stärke, und wie würde sich diese in einem realen Assessment-Center zeigen?",
  "Beschreibe eine Situation, in der ein Teamkollege oder Mitschüler Fehler gemacht hat. Wie hast du reagiert?",
  "Was motiviert dich, Pilot zu werden — und was ist deine größte Sorge in Bezug auf das Auswahlverfahren?",
];
const GENERIC_QUESTIONS_EN = [
  "Describe a situation where you had to make an important decision under time pressure. What did you do and what did you learn?",
  "How do you handle criticism, especially when you disagree with your superior or examiner?",
  "What is your greatest strength, and how would it show in a real assessment centre?",
  "Describe a situation where a teammate or fellow student made mistakes. How did you react?",
  "What motivates you to become a pilot — and what is your biggest concern about the selection process?",
];

export default function InterviewPage() {
  const { user, isGerman } = useAuth();
  const router = useRouter();

  const [phase, setPhase]         = useState<Phase>("setup");
  const [questions, setQuestions] = useState<string[]>([]);
  const [sessionSize, setSessionSize] = useState<SessionSize>("medium");
  const [activeCount, setActiveCount] = useState(0);
  const [currentIdx, setIdx]      = useState(0);
  const [hint, setHint]           = useState<string | null>(null);
  const [loadingHint, setLoadingHint] = useState(false);
  const [interviewRuns, setRuns]  = useState(0);
  const [result, setResult]       = useState<AnalysisResult | null>(null);

  useEffect(() => {
    setRuns(parseInt(localStorage.getItem("pm_interview_run_count") ?? "0", 10));
    const cached = localStorage.getItem("pm_analysis_result_v1");
    if (cached) { try { setResult(JSON.parse(cached)); } catch { /* */ } }

    // Load AI-generated questions
    const aiQ = localStorage.getItem("pm_interview_questions_v1");
    if (aiQ) { try { setQuestions(JSON.parse(aiQ)); } catch { /* */ } }
    else {
      setQuestions(isGerman ? GENERIC_QUESTIONS_DE : GENERIC_QUESTIONS_EN);
    }
  }, [isGerman]);

  const hasAIQuestions = questions.length > 0 &&
    questions[0] !== (isGerman ? GENERIC_QUESTIONS_DE[0] : GENERIC_QUESTIONS_EN[0]);

  const totalQ = activeCount || questions.length;

  function startInterview() {
    const sizeCount = SESSION_SIZES[sessionSize].count;
    const count = sizeCount > 0 ? Math.min(sizeCount, questions.length) : questions.length;
    setActiveCount(count);
    setIdx(0); setHint(null); setPhase("interview");
  }

  function nextQuestion() {
    setHint(null);
    if (currentIdx < totalQ - 1) {
      setIdx(currentIdx + 1);
    } else {
      finish();
    }
  }

  function finish() {
    const newCount = interviewRuns + 1;
    localStorage.setItem("pm_interview_run_count", String(newCount));
    setRuns(newCount);
    setPhase("done");
  }

  async function fetchHint() {
    if (!questions[currentIdx]) return;
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
        body: JSON.stringify({ question: questions[currentIdx], language: isGerman ? "de" : "en" }),
      });
      const json = await res.json();
      setHint(json.hint ?? null);
    } catch { /* ignore */ } finally {
      setLoadingHint(false);
    }
  }

  // ── Setup ─────────────────────────────────────────────────────────────────
  if (phase === "setup") {
    return (
      <div className="min-h-svh flex flex-col" style={{ background: "var(--app-bg)" }}>
        <div className="flex items-center px-4 gap-2" style={{ paddingTop: "max(env(safe-area-inset-top, 12px), 12px)", paddingBottom: 12 }}>
          <button onClick={() => router.back()} className="w-8 h-8 flex items-center justify-center rounded-full text-sm"
            style={{ background: "var(--app-input)" }}>←</button>
          <h1 className="flex-1 text-center font-bold text-base" style={{ color: "var(--app-primary)" }}>
            {t("Interview Simulation","Interview Simulation",isGerman)}
          </h1>
          <div className="w-8" />
        </div>

        <div className="flex-1 px-5 py-4 space-y-5 fade-in">
          {/* Info card */}
          <div className="card p-5 space-y-4">
            <div className="flex items-center gap-3">
              <span className="text-3xl">🎤</span>
              <div>
                <p className="font-bold" style={{ color: "var(--app-primary)" }}>
                  {t("Interview Simulation","Interview Simulation",isGerman)}
                </p>
                <p className="text-xs" style={{ color: "var(--app-secondary)" }}>
                  {t(`${questions.length} Fragen • ${interviewRuns}/3 Durchgänge`,`${questions.length} questions • ${interviewRuns}/3 runs`,isGerman)}
                </p>
              </div>
              {hasAIQuestions && (
                <span className="ml-auto text-xs px-2 py-0.5 rounded-full font-semibold"
                  style={{ background: "rgba(107,94,228,0.15)", color: "#6B5EE4" }}>
                  {t("KI-personalisiert","AI-personalized",isGerman)}
                </span>
              )}
            </div>

            <p className="text-sm" style={{ color: "var(--app-secondary)" }}>
              {t(
                "Beantworte jede Frage laut und vollständig, als würdest du in einem echten Assessment-Interview sitzen. Danach kannst du einen KI-Hinweis abrufen.",
                "Answer each question aloud and fully, as if you were in a real assessment interview. Afterwards, you can request an AI hint.",
                isGerman)}
            </p>

            {/* Run progress */}
            <div className="flex items-center gap-2">
              {[0,1,2].map((i) => (
                <div key={i} className="w-2 h-2 rounded-full"
                  style={{ background: i < interviewRuns ? "#4A9EF8" : "var(--app-border)" }} />
              ))}
              <span className="text-xs ml-1" style={{ color: "var(--app-secondary)" }}>
                {interviewRuns}/3 {t("Durchgänge","runs",isGerman)}
              </span>
            </div>

            {/* Session size */}
            <div className="space-y-2 pt-1">
              <p className="text-xs font-semibold" style={{ color: "var(--app-secondary)" }}>
                {t("Länge","Length",isGerman)}
              </p>
              <div className="flex gap-2">
                {(Object.entries(SESSION_SIZES) as [SessionSize, typeof SESSION_SIZES[SessionSize]][]).map(([key, sz]) => (
                  <button key={key} onClick={() => setSessionSize(key)}
                    className="flex-1 py-2 rounded-xl text-xs font-semibold text-center"
                    style={{
                      background: sessionSize === key ? "rgba(74,158,248,0.15)" : "var(--app-input)",
                      border: `1px solid ${sessionSize === key ? "#4A9EF8" : "transparent"}`,
                      color: sessionSize === key ? "#4A9EF8" : "var(--app-secondary)",
                    }}>
                    <div>{isGerman ? sz.de : sz.en}</div>
                    <div className="opacity-70" style={{ fontSize: "0.65rem", marginTop: 2 }}>{isGerman ? sz.detail : sz.detailEN}</div>
                  </button>
                ))}
              </div>
            </div>
          </div>

          {result && (
            <div className="card p-4">
              <p className="text-xs font-semibold mb-2" style={{ color: "var(--app-secondary)" }}>
                {t("Fokus für diesen Durchgang:","Focus for this session:",isGerman)}
              </p>
              <p className="text-sm" style={{ color: "var(--app-secondary)" }}>
                {result.assessmentAdvice?.slice(0, 120)}…
              </p>
            </div>
          )}
        </div>

        <div className="px-5 pb-safe">
          <button onClick={startInterview} className="btn-primary">
            {interviewRuns === 0
              ? t("Interview starten","Start interview",isGerman)
              : t("Weiteres Interview starten","Start another interview",isGerman)}
          </button>
        </div>
      </div>
    );
  }

  // ── Interview ─────────────────────────────────────────────────────────────
  if (phase === "interview") {
    const q = questions[currentIdx];
    const isLast = currentIdx === totalQ - 1;
    return (
      <div className="min-h-svh flex flex-col" style={{ background: "var(--app-bg)" }}>
        {/* Header — no back button during interview */}
        <div className="px-4" style={{ paddingTop: "max(env(safe-area-inset-top, 12px), 12px)", paddingBottom: 12 }}>
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold" style={{ color: "#4A9EF8" }}>
              {currentIdx + 1} / {totalQ}
            </span>
            <span className="text-xs" style={{ color: "var(--app-tertiary)" }}>
              {t("Interview läuft…","Interview in progress…",isGerman)}
            </span>
            <button onClick={() => { if (confirm(t("Interview beenden?","End interview?",isGerman))) finish(); }}
              className="text-xs px-3 py-1 rounded-full"
              style={{ background: "var(--app-input)", color: "var(--app-secondary)" }}>
              {t("Beenden","End",isGerman)}
            </button>
          </div>
          <div className="mt-2 progress-bar-track">
            <div className="progress-bar-fill" style={{ width: `${((currentIdx + 1) / totalQ) * 100}%` }} />
          </div>
        </div>

        <div className="flex-1 px-5 py-4 space-y-4 fade-in">
          {/* Question card */}
          <div className="card p-6 space-y-4">
            {!hasAIQuestions && GENERIC_CATEGORIES_DE[currentIdx] && (
              <span className="text-xs px-2.5 py-1 rounded-full font-semibold"
                style={{ background: "rgba(74,158,248,0.1)", color: "#4A9EF8" }}>
                {isGerman ? GENERIC_CATEGORIES_DE[currentIdx] : GENERIC_CATEGORIES_EN[currentIdx]}
              </span>
            )}
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 font-bold text-sm"
                style={{ background: "rgba(74,158,248,0.15)", color: "#4A9EF8" }}>
                {currentIdx + 1}
              </div>
              <p className="font-semibold text-base leading-snug flex-1" style={{ color: "var(--app-primary)" }}>
                {q}
              </p>
            </div>

            <p className="text-xs" style={{ color: "var(--app-tertiary)" }}>
              {t("Beantworte die Frage laut und vollständig.","Answer the question aloud and fully.",isGerman)}
            </p>
          </div>

          {/* AI Hint */}
          {hint ? (
            <div className="card p-4 space-y-2"
              style={{ border: "1px solid rgba(107,94,228,0.3)", background: "rgba(107,94,228,0.05)" }}>
              <div className="flex items-center gap-2">
                <span className="text-sm">🧠</span>
                <span className="text-xs font-bold" style={{ color: "#6B5EE4" }}>
                  {t("KI-Hinweis","AI Hint",isGerman)}
                </span>
              </div>
              <p className="text-sm" style={{ color: "var(--app-secondary)" }}>{hint}</p>
            </div>
          ) : (
            <button onClick={fetchHint} disabled={loadingHint}
              className="w-full py-3 rounded-xl text-sm font-semibold flex items-center justify-center gap-2"
              style={{ background: "rgba(107,94,228,0.12)", color: "#6B5EE4", border: "1px solid rgba(107,94,228,0.2)" }}>
              {loadingHint ? <><div className="spinner" style={{ width: 16, height: 16, borderColor: "rgba(107,94,228,0.3)", borderTopColor: "#6B5EE4" }} /></> : "🧠"}
              {loadingHint ? t("Lade Hinweis…","Loading hint…",isGerman) : t("KI-Hinweis abrufen","Get AI hint",isGerman)}
            </button>
          )}
        </div>

        <div className="px-5 pb-safe">
          <button onClick={nextQuestion} className="btn-primary">
            {isLast ? t("Interview abschließen","Finish interview",isGerman) : t("Nächste Frage","Next question",isGerman)}
          </button>
        </div>
      </div>
    );
  }

  // ── Done ──────────────────────────────────────────────────────────────────
  return (
    <div className="min-h-svh flex flex-col items-center justify-center px-5 space-y-6" style={{ background: "var(--app-bg)" }}>
      <div className="text-5xl text-center">🏆</div>
      <h2 className="text-2xl font-bold text-center" style={{ color: "var(--app-primary)" }}>
        {t("Durchgang abgeschlossen!","Session complete!",isGerman)}
      </h2>
      <p className="text-sm text-center" style={{ color: "var(--app-secondary)" }}>
        {interviewRuns >= 3
          ? t("Großartig — du hast bereits 3 Durchgänge absolviert!","Great — you've completed 3 sessions!",isGerman)
          : t(`${interviewRuns}/3 Durchgänge absolviert. Regelmäßiges Üben macht den Unterschied.`,`${interviewRuns}/3 sessions done. Regular practice makes the difference.`,isGerman)}
      </p>
      <div className="flex gap-3 w-full max-w-xs">
        <button onClick={() => { setPhase("setup"); setHint(null); }}
          className="flex-1 py-3 rounded-xl font-semibold text-sm"
          style={{ background: "var(--app-input)", color: "var(--app-primary)" }}>
          {t("Nochmals","Again",isGerman)}
        </button>
        <button onClick={() => router.back()}
          className="flex-1 py-3 rounded-xl font-semibold text-sm"
          style={{ background: "#4A9EF8", color: "white" }}>
          {t("Fertig","Done",isGerman)}
        </button>
      </div>
    </div>
  );
}
