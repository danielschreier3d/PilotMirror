"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { supabase } from "@/lib/supabase";
import { SURVEY_QUESTIONS, getLicenseSpecificQuestions } from "@/lib/questions";
import type { Answers } from "@/lib/types";
import QuestionCard from "@/components/QuestionCard";

export default function SurveyPage() {
  const { user, isGerman } = useAuth();
  const router = useRouter();

  const questions = [
    ...SURVEY_QUESTIONS,
    ...getLicenseSpecificQuestions(user?.flightLicenses ?? []),
  ];

  const [answers, setAnswers]     = useState<Answers>({});
  const [currentIdx, setIdx]      = useState(0);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError]         = useState<string | null>(null);

  const q = questions[currentIdx];
  if (!q) return null;

  // Group questions into sections for display
  const sections = Array.from(new Set(questions.map((x) => x.section)));
  const currentSection = q.section;
  const sectionTitle = isGerman ? q.sectionTitle : q.sectionTitleEN;

  function answer(value: Answers[string]) {
    setAnswers((prev) => ({ ...prev, [q.id]: value }));
  }

  function next() {
    if (currentIdx < questions.length - 1) setIdx(currentIdx + 1);
    else submit();
  }

  function prev() {
    if (currentIdx > 0) setIdx(currentIdx - 1);
  }

  const canProceed = (() => {
    const a = answers[q.id];
    if (!a) return false;
    if (a.type === "multipleChoice") return a.value.length > 0;
    if (a.type === "text") return true; // optional open text
    return true;
  })();

  const isLastQuestion = currentIdx === questions.length - 1;

  async function submit() {
    if (!user) return;
    setSubmitting(true); setError(null);
    try {
      // Get or create session
      let sessionId = localStorage.getItem("pm_session_id");
      if (!sessionId) {
        const newId = crypto.randomUUID();
        await supabase.from("assessment_sessions").insert({ id: newId, candidate_id: user.id });
        sessionId = newId;
        localStorage.setItem("pm_session_id", newId);
      }

      // Save self-responses
      for (const [questionId, ans] of Object.entries(answers)) {
        let answerType = "";
        let answerValue = "";
        if (ans.type === "multipleChoice") { answerType = "multiple"; answerValue = JSON.stringify(ans.value); }
        else if (ans.type === "singleChoice") { answerType = "single"; answerValue = ans.value; }
        else if (ans.type === "rating") { answerType = "rating"; answerValue = String(ans.value); }
        else if (ans.type === "text") { answerType = "text"; answerValue = ans.value; }

        await supabase.from("self_responses").upsert({
          id: crypto.randomUUID(),
          session_id: sessionId,
          question_id: questionId,
          answer_type: answerType,
          answer_value: answerValue,
        }, { onConflict: "session_id,question_id" });
      }

      // Cache locally
      localStorage.setItem("pm_self_responses", JSON.stringify(answers));
      router.replace("/dashboard");
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Error saving");
    } finally {
      setSubmitting(false);
    }
  }

  const progress = (currentIdx + 1) / questions.length;

  return (
    <div className="min-h-svh flex flex-col" style={{ background: "var(--app-bg)" }}>
      {/* Header */}
      <div className="sticky top-0 z-10 px-4 pt-safe-top pb-3 space-y-2"
        style={{ background: "var(--app-bg)", borderBottom: "1px solid var(--app-border)", paddingTop: "max(env(safe-area-inset-top, 12px), 12px)" }}>
        <div className="flex items-center justify-between">
          <button onClick={prev} disabled={currentIdx === 0}
            className="w-8 h-8 flex items-center justify-center rounded-full text-sm"
            style={{ background: "var(--app-input)", opacity: currentIdx === 0 ? 0.3 : 1 }}>
            ←
          </button>
          <div className="text-center">
            <div className="text-xs font-semibold" style={{ color: "#4A9EF8" }}>{sectionTitle}</div>
            <div className="text-xs" style={{ color: "var(--app-tertiary)" }}>
              {currentIdx + 1} / {questions.length}
            </div>
          </div>
          <button onClick={() => router.back()} className="text-xs" style={{ color: "var(--app-tertiary)" }}>
            {isGerman ? "Abbrechen" : "Cancel"}
          </button>
        </div>
        <div className="progress-bar-track">
          <div className="progress-bar-fill" style={{ width: `${progress * 100}%` }} />
        </div>
      </div>

      {/* Question */}
      <div className="flex-1 px-4 py-5">
        <QuestionCard
          key={q.id}
          question={q}
          answer={answers[q.id]}
          mode="selfAssessment"
          isGerman={isGerman}
          onAnswer={answer}
        />
      </div>

      {/* Next button */}
      <div className="px-4 pb-safe">
        {error && <p className="text-sm text-center mb-2" style={{ color: "#FF6B6B" }}>{error}</p>}
        <button
          onClick={next}
          disabled={q.type !== "openText" && !canProceed || submitting}
          className="btn-primary mb-4">
          {submitting ? <div className="spinner" /> : isLastQuestion
            ? (isGerman ? "Abschließen" : "Submit")
            : (isGerman ? "Weiter" : "Next")}
        </button>
      </div>
    </div>
  );
}
