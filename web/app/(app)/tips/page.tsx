"use client";

import { useState, useEffect } from "react";
import { useAuth } from "@/lib/auth-context";
import type { AnalysisResult } from "@/lib/types";

function t(de: string, en: string, g: boolean) { return g ? de : en; }

const STATIC_TIPS = {
  group: {
    de: [
      "Melde dich innerhalb der ersten 2 Minuten zu Wort — Schweigen wird als Desinteresse gewertet",
      "Erkenne die Ideen anderer an, bevor du sie weiterentwickelst",
      "Achte auf deine Redezeit — Qualität vor Quantität",
      "Biete an, die Gruppenposition zusammenzufassen — zeigt Führungsstärke",
      "Bleib sichtbar ruhig — Assessoren beobachten Körpersprache genauso wie Worte",
    ],
    en: [
      "Speak up within the first 2 minutes — silence is misread as disinterest",
      "Acknowledge others' ideas before building on them",
      "Watch your airtime — quality over quantity",
      "Offer to summarise the group's position — shows leadership",
      "Stay visibly calm — assessors watch body language as much as words",
    ],
  },
  interview: {
    de: [
      "Nutze das STAR-Format: Situation, Task (Aufgabe), Action (Handlung), Result (Ergebnis)",
      "Bereite 5 Beispiele für Entscheidungen unter Druck vor",
      "Zeige Selbstreflexion — benenne eine echte Schwäche mit einer Entwicklungsgeschichte",
      "Recherchiere die Werte der Airline und stimme deine Antworten darauf ab",
      "Übe, Antworten in unter 90 Sekunden zu geben",
    ],
    en: [
      "Use STAR format: Situation, Task, Action, Result",
      "Prepare 5 examples of decisions made under pressure",
      "Show self-awareness — acknowledge a real weakness with a recovery story",
      "Research the airline's values and align your answers",
      "Practice answering in under 90 seconds per question",
    ],
  },
  decision: {
    de: [
      "Im Simulator: Kommuniziere deine Absicht laut, bevor du handelst",
      "Übe zeitlich begrenzte Entscheidungen — max. 30 Sekunden für Routineentscheidungen",
      "Verbalisiere deine Risikoeinschätzung in Rollenspielszenarien",
      "Bei Unsicherheit: Sag, was du denkst — Assessoren schätzen Transparenz",
      "Zeige, dass du dich anpassen kannst, wenn neue Informationen mitten in einer Aufgabe eintreffen",
    ],
    en: [
      "In simulators: state your intent out loud before acting",
      "Practice time-boxed decisions — 30 seconds max for routine choices",
      "Verbalize your risk assessment in role-play scenarios",
      "If unsure, say what you're thinking — assessors value transparency",
      "Show you can adapt when new information arrives mid-task",
    ],
  },
  awareness: {
    de: [
      "Kenne dein Persönlichkeitsprofil — dein Report ist dein Leitfaden",
      "Falls andere dich als zurückhaltend wahrnehmen: Übe selbstbewussteres Auftreten",
      "Falls andere dich als dominant wahrnehmen: Übe aktives Zuhören",
      "Sei konsistent zwischen deinen Interview-Antworten und deinem beobachtbaren Verhalten",
      "Assessoren vergleichen, was du über dich sagst, mit dem, was sie beobachten",
    ],
    en: [
      "Know your personality profile — your report is your guide",
      "If others see you as reserved — practice assertive phrasing",
      "If others see you as dominant — practice active listening",
      "Be consistent between interview answers and observed behavior",
      "Assessors compare what you say about yourself with what they see",
    ],
  },
};

const CARDS: { key: keyof typeof STATIC_TIPS; icon: string; color: string; titleDE: string; titleEN: string }[] = [
  { key: "group",    icon: "👥", color: "#4A9EF8", titleDE: "Gruppenübung",      titleEN: "Group Exercise"   },
  { key: "interview",icon: "🎤", color: "#FF9F0A", titleDE: "Interview",          titleEN: "Interview"        },
  { key: "decision", icon: "🔀", color: "#34C759", titleDE: "Entscheidungsverhalten", titleEN: "Decision Making" },
  { key: "awareness",icon: "🧠", color: "#6B5EE4", titleDE: "Selbstwahrnehmung",  titleEN: "Self-Awareness"   },
];

export default function TipsPage() {
  const { user, isGerman } = useAuth();
  const [result, setResult] = useState<AnalysisResult | null>(null);

  useEffect(() => {
    const cached = localStorage.getItem("pm_analysis_result_v1");
    if (cached) { try { setResult(JSON.parse(cached)); } catch { /* */ } }
  }, []);

  const personalized: Record<string, string[]> = {
    group:     result?.groupExerciseTips ?? [],
    interview: result?.interviewTips ?? [],
    decision:  result?.decisionMakingTips ?? [],
    awareness: result?.selfAwarenessTips ?? [],
  };

  return (
    <div>
      {/* Nav bar */}
      <div className="sticky top-0 z-40 px-4"
        style={{ background: "var(--app-bg)", borderBottom: "1px solid var(--app-border)",
          paddingTop: "max(env(safe-area-inset-top, 12px), 12px)", paddingBottom: 10 }}>
        <h1 className="text-xl font-bold text-center" style={{ color: "var(--app-primary)" }}>
          {t("Vorbereitungsguide", "Preparation Guide", isGerman)}
        </h1>
        {user?.assessmentType && (
          <div className="flex justify-center mt-1">
            <span className="text-xs px-3 py-1 rounded-full font-semibold"
              style={{ background: "rgba(74,158,248,0.15)", color: "#4A9EF8" }}>
              {user.assessmentType}
            </span>
          </div>
        )}
      </div>

      <div className="px-4 py-4 space-y-4 pb-safe">
        {CARDS.map(({ key, icon, color, titleDE, titleEN }) => {
          const tips = personalized[key]?.length > 0
            ? personalized[key]
            : isGerman ? STATIC_TIPS[key].de : STATIC_TIPS[key].en;
          const isPersonalized = (personalized[key]?.length ?? 0) > 0;
          return (
            <AdviceCard key={key}
              icon={icon} color={color}
              title={isGerman ? titleDE : titleEN}
              tips={tips}
              isPersonalized={isPersonalized}
              isGerman={isGerman} />
          );
        })}
        <div className="h-4" />
      </div>
    </div>
  );
}

function AdviceCard({ icon, color, title, tips, isPersonalized, isGerman }: {
  icon: string; color: string; title: string; tips: string[];
  isPersonalized: boolean; isGerman: boolean;
}) {
  return (
    <div className="rounded-2xl p-5 space-y-4"
      style={{ background: "var(--app-card)", border: "1px solid var(--app-border)" }}>
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl flex items-center justify-center text-xl"
          style={{ background: `${color}25` }}>
          {icon}
        </div>
        <span className="font-bold text-base" style={{ color: "var(--app-primary)" }}>{title}</span>
        {isPersonalized && (
          <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full"
            style={{ background: "rgba(52,199,89,0.15)", color: "#34C759" }}>
            {isGerman ? "Personalisiert" : "Personalized"}
          </span>
        )}
      </div>
      <div className="space-y-3">
        {tips.map((tip, i) => (
          <div key={i} className="flex items-start gap-3">
            <div className="w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0 text-xs font-bold"
              style={{ background: `${color}20`, color }}>
              {i + 1}
            </div>
            <p className="text-sm flex-1" style={{ color: "var(--app-primary)", lineHeight: 1.5 }}>{tip}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
