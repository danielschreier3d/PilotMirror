"use client";

import { useState, useEffect } from "react";
import type { Question, AnswerValue, SurveyMode } from "@/lib/types";
import { displayText, displayOptions, displayPlaceholder } from "@/lib/types";

interface Props {
  question: Question;
  answer?: AnswerValue;
  mode?: SurveyMode;
  candidateName?: string;
  isGerman: boolean;
  onAnswer: (v: AnswerValue) => void;
}

export default function QuestionCard({ question: q, answer, mode = "selfAssessment", candidateName, isGerman, onAnswer }: Props) {
  const qText    = displayText(q, mode, isGerman, candidateName);
  const options  = displayOptions(q, isGerman);
  const canonical = q.options ?? [];

  return (
    <div className="rounded-2xl p-5 space-y-5 fade-in"
      style={{ background: "var(--app-card)", border: "1px solid var(--app-border)" }}>
      <p className="font-semibold text-base leading-snug" style={{ color: "var(--app-primary)" }}>
        {qText}
      </p>

      {q.type === "traitSelection" && (
        <TraitGrid canonical={canonical} display={options ?? canonical} answer={answer} onAnswer={onAnswer} />
      )}
      {q.type === "forcedChoice" && (
        <ForcedChoice canonical={canonical} display={options ?? canonical} answer={answer} onAnswer={onAnswer} />
      )}
      {q.type === "ratingScale" && (
        <RatingScale answer={answer} onAnswer={onAnswer} isGerman={isGerman} />
      )}
      {q.type === "openText" && (
        <OpenText q={q} answer={answer} isGerman={isGerman} onAnswer={onAnswer} />
      )}
    </div>
  );
}

// ─── Trait Grid ───────────────────────────────────────────────────────────────

function TraitGrid({ canonical, display, answer, onAnswer }: {
  canonical: string[]; display: string[]; answer?: AnswerValue;
  onAnswer: (v: AnswerValue) => void;
}) {
  const selected: string[] = answer?.type === "multipleChoice" ? answer.value : [];

  function toggle(key: string) {
    const next = selected.includes(key)
      ? selected.filter((x) => x !== key)
      : [...selected, key];
    onAnswer({ type: "multipleChoice", value: next });
  }

  return (
    <div className="flow-wrap">
      {display.map((label, i) => {
        const key = canonical[i];
        const isOn = selected.includes(key);
        return (
          <button key={key} onClick={() => toggle(key)}
            className="px-3.5 py-2 rounded-full text-sm font-medium transition-all"
            style={{
              background: isOn ? "#4A9EF8" : "var(--app-input)",
              color: isOn ? "white" : "var(--app-primary)",
              border: "none",
            }}>
            {label}
          </button>
        );
      })}
    </div>
  );
}

// ─── Forced Choice ────────────────────────────────────────────────────────────

function ForcedChoice({ canonical, display, answer, onAnswer }: {
  canonical: string[]; display: string[]; answer?: AnswerValue;
  onAnswer: (v: AnswerValue) => void;
}) {
  const selected: string = answer?.type === "singleChoice" ? answer.value : "";

  return (
    <div className="space-y-2.5">
      {display.map((label, i) => {
        const key = canonical[i];
        const isOn = selected === key;
        return (
          <button key={key} onClick={() => onAnswer({ type: "singleChoice", value: key })}
            className="w-full text-left rounded-xl p-3.5 transition-all"
            style={{
              background: isOn ? "rgba(74,158,248,0.18)" : "var(--app-card)",
              border: `1px solid ${isOn ? "rgba(74,158,248,0.7)" : "var(--app-border)"}`,
            }}>
            <div className="flex items-center gap-3">
              <span className="flex-1 text-sm" style={{ color: isOn ? "var(--app-primary)" : "var(--app-primary)" }}>
                {label}
              </span>
              <div className="w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0"
                style={{ background: isOn ? "#4A9EF8" : "transparent", border: `2px solid ${isOn ? "#4A9EF8" : "var(--app-border)"}` }}>
                {isOn && <div className="w-2 h-2 rounded-full bg-white" />}
              </div>
            </div>
          </button>
        );
      })}
    </div>
  );
}

// ─── Rating Scale ─────────────────────────────────────────────────────────────

function RatingScale({ answer, onAnswer, isGerman }: {
  answer?: AnswerValue; onAnswer: (v: AnswerValue) => void; isGerman: boolean;
}) {
  const current: number = answer?.type === "rating" ? answer.value : 0;

  return (
    <div className="space-y-3">
      <div className="flex justify-between items-center">
        {[1,2,3,4,5].map((i) => (
          <button key={i} onClick={() => onAnswer({ type: "rating", value: i })}
            className={`rating-circle ${i <= current ? "active" : ""}`}
            style={{ transform: i === current ? "scale(1.1)" : "scale(1)" }}>
            {i}
          </button>
        ))}
      </div>
      <div className="flex justify-between text-xs" style={{ color: "var(--app-tertiary)" }}>
        <span>{isGerman ? "Niedrig" : "Low"}</span>
        <span>{isGerman ? "Hoch" : "High"}</span>
      </div>
    </div>
  );
}

// ─── Open Text ────────────────────────────────────────────────────────────────

function OpenText({ q, answer, isGerman, onAnswer }: {
  q: Question; answer?: AnswerValue; isGerman: boolean;
  onAnswer: (v: AnswerValue) => void;
}) {
  const [text, setText] = useState(answer?.type === "text" ? answer.value : "");

  useEffect(() => {
    setText(answer?.type === "text" ? answer.value : "");
  }, [answer]);

  function handleChange(v: string) {
    setText(v);
    onAnswer({ type: "text", value: v });
  }

  const placeholder = displayPlaceholder(q, isGerman) ?? (isGerman ? "Antwort eingeben…" : "Enter your answer…");

  return (
    <textarea
      value={text}
      onChange={(e) => handleChange(e.target.value)}
      placeholder={placeholder}
      rows={4}
      className="w-full resize-none rounded-xl p-3.5 text-sm outline-none transition-colors"
      style={{
        background: "var(--app-card)",
        border: "1px solid var(--app-border)",
        color: "var(--app-primary)",
      }}
      onFocus={(e) => (e.target.style.borderColor = "#4A9EF8")}
      onBlur={(e) => (e.target.style.borderColor = "var(--app-border)")}
    />
  );
}
