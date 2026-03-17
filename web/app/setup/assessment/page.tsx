"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import type { AssessmentType } from "@/lib/types";

const ASSESSMENTS: { type: AssessmentType; icon: string; descDE: string; descEN: string }[] = [
  { type: "European Flight Academy", icon: "🛫",
    descDE: "Vorbereitung auf das EFA Multi-Crew-Selection",
    descEN: "Prepare for the EFA multi-crew selection" },
  { type: "Austrian Airlines", icon: "🇦🇹",
    descDE: "Vorbereitung auf das Austrian Airlines Assessment",
    descEN: "Prepare for the Austrian Airlines assessment" },
  { type: "Condor", icon: "🌅",
    descDE: "Vorbereitung auf das Condor Piloten-Assessment",
    descEN: "Prepare for the Condor pilot assessment" },
  { type: "AeroLogic", icon: "📦",
    descDE: "Vorbereitung auf das AeroLogic Assessment",
    descEN: "Prepare for the AeroLogic assessment" },
  { type: "General Pilot Assessment", icon: "✅",
    descDE: "Allgemeines Piloten-Auswahlverfahren",
    descEN: "General airline pilot selection process" },
];

export default function AssessmentSelectPage() {
  const { isGerman, updateAssessmentType } = useAuth();
  const router = useRouter();
  const [selected, setSelected] = useState<AssessmentType | null>(null);
  const [saving, setSaving] = useState(false);

  async function proceed() {
    if (!selected) return;
    setSaving(true);
    await updateAssessmentType(selected);
    router.replace("/setup/licenses");
  }

  return (
    <div className="min-h-svh px-5 py-10 space-y-6" style={{ background: "var(--app-bg)" }}>
      <div className="space-y-2">
        <h1 className="text-2xl font-bold" style={{ color: "var(--app-primary)" }}>
          {isGerman ? "Für welches Assessment bereitest du dich vor?" : "Which assessment are you preparing for?"}
        </h1>
        <p className="text-sm" style={{ color: "var(--app-secondary)" }}>
          {isGerman ? "Wähle dein Ziel — die Analyse wird darauf angepasst." : "Choose your goal — the analysis will be tailored to it."}
        </p>
      </div>

      <div className="space-y-3">
        {ASSESSMENTS.map(({ type, icon, descDE, descEN }) => {
          const isOn = selected === type;
          return (
            <button key={type} onClick={() => setSelected(type)}
              className="w-full text-left p-4 rounded-2xl transition-all"
              style={{
                background: isOn ? "rgba(74,158,248,0.12)" : "var(--app-card)",
                border: `1px solid ${isOn ? "rgba(74,158,248,0.5)" : "var(--app-border)"}`,
              }}>
              <div className="flex items-center gap-3">
                <span className="text-2xl">{icon}</span>
                <div className="flex-1">
                  <div className="font-semibold text-sm" style={{ color: "var(--app-primary)" }}>{type}</div>
                  <div className="text-xs mt-0.5" style={{ color: "var(--app-secondary)" }}>
                    {isGerman ? descDE : descEN}
                  </div>
                </div>
                <div className="w-5 h-5 rounded-full flex items-center justify-center"
                  style={{ background: isOn ? "#4A9EF8" : "transparent", border: `2px solid ${isOn ? "#4A9EF8" : "var(--app-border)"}` }}>
                  {isOn && <div className="w-2 h-2 rounded-full bg-white" />}
                </div>
              </div>
            </button>
          );
        })}
      </div>

      <button className="btn-primary" disabled={!selected || saving} onClick={proceed}>
        {saving ? <div className="spinner" /> : (isGerman ? "Weiter" : "Continue")}
      </button>
    </div>
  );
}
