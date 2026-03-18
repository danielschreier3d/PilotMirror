"use client";

import { Suspense } from "react";
import { useState, useEffect, use } from "react";
import { useSearchParams } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { SURVEY_QUESTIONS } from "@/lib/questions";
import type { Answers, RelationshipType } from "@/lib/types";
import { RELATIONSHIP_LABELS } from "@/lib/types";
import QuestionCard from "@/components/QuestionCard";

type Phase = "intro" | "survey" | "motivation" | "done" | "error";

function useIsGerman() {
  const [isGerman, setIsGerman] = useState(false);
  useEffect(() => { setIsGerman(navigator.language.startsWith("de")); }, []);
  return isGerman;
}

function t(de: string, en: string, isGerman: boolean) { return isGerman ? de : en; }

function FeedbackContent() {
  const searchParams = useSearchParams();
  const token = searchParams.get("token") ?? "";
  const isGerman = useIsGerman();

  const [phase, setPhase]             = useState<Phase>("intro");
  const [candidateName, setCandidateName] = useState("");
  const [name, setName]               = useState("");
  const [relationship, setRelationship] = useState<RelationshipType>("friend");
  const [answers, setAnswers]         = useState<Answers>({});
  const [currentIdx, setIdx]          = useState(0);
  const [submitting, setSubmitting]   = useState(false);
  const [errorMsg, setErrorMsg]       = useState("");
  const [linkId, setLinkId]           = useState("");
  const [confidenceRating, setConfidenceRating] = useState(0);
  const [wishText, setWishText]       = useState("");

  useEffect(() => {
    if (!token) { setPhase("error"); setErrorMsg("Missing token."); return; }
    async function resolve() {
      try {
        const { data, error } = await supabase.rpc("get_link_by_token", { p_token: token });
        if (error || !data?.[0]) { setPhase("error"); setErrorMsg(t("Ungültiger oder abgelaufener Link.", "Invalid or expired link.", isGerman)); return; }
        const { link_id, session_id } = data[0] as { link_id: string; session_id: string };
        setLinkId(link_id);
        const { data: session } = await supabase.from("assessment_sessions")
          .select("candidate_id").eq("id", session_id).single();
        if (session?.candidate_id) {
          const { data: userRow } = await supabase.from("users")
            .select("full_name").eq("id", session.candidate_id).single();
          if (userRow?.full_name) setCandidateName((userRow.full_name as string).split(" ")[0]);
        }
      } catch { setPhase("error"); setErrorMsg("Network error."); }
    }
    resolve();
  }, [token, isGerman]);

  const questions = SURVEY_QUESTIONS;
  const q = questions[currentIdx];

  function answer(value: Answers[string]) { setAnswers((prev) => ({ ...prev, [q.id]: value })); }
  function next() { if (currentIdx < questions.length - 1) setIdx(currentIdx + 1); else setPhase("motivation"); }
  function prev() { if (currentIdx > 0) setIdx(currentIdx - 1); }

  async function submit() {
    setSubmitting(true);
    try {
      const respondentId = crypto.randomUUID();
      await supabase.from("respondents").insert({ id: respondentId, feedback_link_id: linkId, name, relationship, confidence_rating: confidenceRating || null, wish_text: wishText || null });
      for (const [questionId, ans] of Object.entries(answers)) {
        let answerType = "", answerValue = "";
        if (ans.type === "multipleChoice") { answerType = "multiple"; answerValue = JSON.stringify(ans.value); }
        else if (ans.type === "singleChoice") { answerType = "single"; answerValue = ans.value; }
        else if (ans.type === "rating") { answerType = "rating"; answerValue = String(ans.value); }
        else if (ans.type === "text") { answerType = "text"; answerValue = ans.value; }
        await supabase.from("survey_responses").insert({ id: crypto.randomUUID(), respondent_id: respondentId, question_id: questionId, answer_type: answerType, answer_value: answerValue });
      }
      await supabase.rpc("increment_response_count", { p_link_id: linkId });
      setPhase("done");
    } catch (e: unknown) {
      setErrorMsg(e instanceof Error ? e.message : "Submission error");
    } finally { setSubmitting(false); }
  }

  if (phase === "error") return <CenteredCard><div className="text-4xl text-center">❌</div><p className="text-center" style={{ color: "var(--app-secondary)" }}>{errorMsg}</p></CenteredCard>;

  if (phase === "done") return <CenteredCard>
    <div className="text-5xl text-center">✅</div>
    <h2 className="text-xl font-bold text-center" style={{ color: "var(--app-primary)" }}>{t("Vielen Dank!", "Thank you!", isGerman)}</h2>
    <p className="text-sm text-center" style={{ color: "var(--app-secondary)" }}>
      {t(`Dein Feedback für ${candidateName || "den Kandidaten"} wurde erfolgreich übermittelt.`, `Your feedback for ${candidateName || "the candidate"} has been successfully submitted.`, isGerman)}
    </p>
  </CenteredCard>;

  if (phase === "intro") return (
    <div className="min-h-svh flex items-center justify-center px-5" style={{ background: "var(--app-bg)" }}>
      <div className="max-w-sm w-full space-y-6 fade-in">
        <div className="text-center space-y-3">
          <div className="text-5xl">✈️</div>
          <h1 className="text-2xl font-bold" style={{ color: "var(--app-primary)" }}>PilotMirror</h1>
          <p className="text-sm" style={{ color: "var(--app-secondary)" }}>
            {candidateName
              ? t(`${candidateName} bereitet sich auf ein Pilotenauswahlverfahren vor und bittet dich um eine ehrliche, anonyme Einschätzung.`, `${candidateName} is preparing for a pilot assessment and asks for your honest, anonymous feedback.`, isGerman)
              : t("Bitte fülle diesen kurzen, anonymen Fragebogen aus.", "Please fill out this short, anonymous questionnaire.", isGerman)}
          </p>
          <p className="text-xs" style={{ color: "var(--app-tertiary)" }}>{t("Ca. 3–5 Minuten • Anonym • Keine Registrierung nötig", "~3–5 minutes • Anonymous • No registration needed", isGerman)}</p>
        </div>
        <div className="card p-4 space-y-4">
          <div>
            <label className="text-xs font-semibold mb-1.5 block" style={{ color: "var(--app-secondary)" }}>{t("Dein Vorname (optional)", "Your first name (optional)", isGerman)}</label>
            <input type="text" value={name} onChange={(e) => setName(e.target.value)} placeholder={t("z.B. Maria", "e.g. John", isGerman)} className="input-field" />
          </div>
          <div>
            <label className="text-xs font-semibold mb-2 block" style={{ color: "var(--app-secondary)" }}>{t("Wie kennst du diese Person?", "How do you know this person?", isGerman)}</label>
            <div className="grid grid-cols-2 gap-2">
              {(Object.entries(RELATIONSHIP_LABELS) as [RelationshipType, { de: string; en: string }][]).map(([rel, labels]) => (
                <button key={rel} onClick={() => setRelationship(rel)}
                  className="py-2 px-3 rounded-xl text-sm font-medium transition-all"
                  style={{ background: relationship === rel ? "rgba(74,158,248,0.15)" : "var(--app-input)", border: `1px solid ${relationship === rel ? "#4A9EF8" : "transparent"}`, color: relationship === rel ? "#4A9EF8" : "var(--app-secondary)" }}>
                  {isGerman ? labels.de : labels.en}
                </button>
              ))}
            </div>
          </div>
        </div>
        <button className="btn-primary" onClick={() => setPhase("survey")}>{t("Fragebogen starten", "Start questionnaire", isGerman)}</button>
      </div>
    </div>
  );

  if (phase === "motivation") return (
    <div className="min-h-svh flex items-center justify-center px-5" style={{ background: "var(--app-bg)" }}>
      <div className="max-w-sm w-full space-y-5 fade-in">
        <h2 className="text-xl font-bold text-center" style={{ color: "var(--app-primary)" }}>{t("Fast fertig!", "Almost done!", isGerman)}</h2>
        <div className="card p-5 space-y-5">
          <div>
            <p className="text-sm font-semibold mb-3" style={{ color: "var(--app-primary)" }}>
              {candidateName ? t(`Wie sehr glaubst du, dass ${candidateName} das Assessment bestehen wird?`, `How confident are you that ${candidateName} will pass the assessment?`, isGerman)
                : t("Wie sehr glaubst du, dass die Person das Assessment bestehen wird?", "How confident are you that this person will pass the assessment?", isGerman)}
            </p>
            <div className="flex justify-between">{[1,2,3,4,5].map((i) => (<button key={i} onClick={() => setConfidenceRating(i)} className={`rating-circle ${i <= confidenceRating ? "active" : ""}`}>{i}</button>))}</div>
            <div className="flex justify-between text-xs mt-2" style={{ color: "var(--app-tertiary)" }}><span>{t("Unwahrscheinlich", "Unlikely", isGerman)}</span><span>{t("Sehr wahrscheinlich", "Very likely", isGerman)}</span></div>
          </div>
          <div>
            <p className="text-sm font-semibold mb-2" style={{ color: "var(--app-primary)" }}>
              {candidateName ? t(`Hast du eine persönliche Botschaft oder Wunsch für ${candidateName}?`, `Do you have a personal message or wish for ${candidateName}?`, isGerman)
                : t("Hast du eine persönliche Botschaft?", "Do you have a personal message?", isGerman)}
            </p>
            <textarea value={wishText} onChange={(e) => setWishText(e.target.value)} placeholder={t("z.B. Ich wünsche dir viel Erfolg!", "e.g. I wish you all the best!", isGerman)} rows={3}
              className="w-full resize-none rounded-xl p-3.5 text-sm outline-none"
              style={{ background: "var(--app-input)", border: "1px solid var(--app-border)", color: "var(--app-primary)" }} />
          </div>
        </div>
        {errorMsg && <p className="text-sm text-center" style={{ color: "#FF6B6B" }}>{errorMsg}</p>}
        <button className="btn-primary" onClick={submit} disabled={submitting}>{submitting ? <div className="spinner" /> : t("Feedback absenden", "Submit feedback", isGerman)}</button>
      </div>
    </div>
  );

  const progress = (currentIdx + 1) / questions.length;
  return (
    <div className="min-h-svh flex flex-col" style={{ background: "var(--app-bg)" }}>
      <div className="sticky top-0 z-10 px-4 pb-3 space-y-2"
        style={{ background: "var(--app-bg)", borderBottom: "1px solid var(--app-border)", paddingTop: "max(env(safe-area-inset-top, 12px), 12px)" }}>
        <div className="flex items-center justify-between">
          <button onClick={prev} disabled={currentIdx === 0} className="w-8 h-8 flex items-center justify-center rounded-full text-sm" style={{ background: "var(--app-input)", opacity: currentIdx === 0 ? 0.3 : 1 }}>←</button>
          <div className="text-center">
            <div className="text-xs font-semibold" style={{ color: "#4A9EF8" }}>{isGerman ? q.sectionTitle : q.sectionTitleEN}</div>
            <div className="text-xs" style={{ color: "var(--app-tertiary)" }}>{currentIdx + 1} / {questions.length}</div>
          </div>
          <div className="w-8" />
        </div>
        <div className="progress-bar-track"><div className="progress-bar-fill" style={{ width: `${progress * 100}%` }} /></div>
      </div>
      <div className="flex-1 px-4 py-5">
        <QuestionCard key={q.id} question={q} answer={answers[q.id]} mode="respondent" candidateName={candidateName || undefined} isGerman={isGerman} onAnswer={answer} />
      </div>
      <div className="px-4" style={{ paddingBottom: "max(env(safe-area-inset-bottom, 16px), 16px)" }}>
        <button onClick={next} disabled={q.type !== "openText" && !answers[q.id]} className="btn-primary">
          {currentIdx === questions.length - 1 ? (isGerman ? "Weiter" : "Continue") : (isGerman ? "Weiter" : "Next")}
        </button>
      </div>
    </div>
  );
}

function CenteredCard({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-center min-h-svh px-5" style={{ background: "var(--app-bg)" }}>
      <div className="card max-w-sm w-full p-8 space-y-4 fade-in">{children}</div>
    </div>
  );
}

export default function FeedbackPage() {
  return (
    <Suspense fallback={<div className="flex items-center justify-center min-h-svh" style={{ background: "var(--app-bg)" }}><div className="spinner" /></div>}>
      <FeedbackContent />
    </Suspense>
  );
}
