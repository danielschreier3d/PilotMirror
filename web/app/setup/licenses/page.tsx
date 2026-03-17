"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import type { FlightLicense } from "@/lib/types";

const LICENSES: {
  value: FlightLicense; icon: string;
  labelDE: string; labelEN: string;
  descDE: string; descEN: string;
}[] = [
  { value: "PPL", icon: "✈️", labelDE: "PPL (Privatpilotenlizenz)", labelEN: "PPL (Private Pilot Licence)",
    descDE: "Privatpilotenlizenz für Motorflugzeuge", descEN: "Private pilot licence for powered aircraft" },
  { value: "TMG", icon: "🛩️", labelDE: "TMG (Motorsegler)", labelEN: "TMG (Touring Motor Glider)",
    descDE: "Lizenz für motorisierte Segelflugzeuge", descEN: "Licence for touring motor gliders" },
  { value: "LAPL", icon: "🛫", labelDE: "LAPL (Leichte Luftfahrzeuge)", labelEN: "LAPL (Light Aircraft)",
    descDE: "Lizenz für leichte Luftfahrzeuge", descEN: "Licence for light aircraft" },
  { value: "UL", icon: "🪂", labelDE: "UL (Ultraleichtflugzeug)", labelEN: "Ultralight Aircraft",
    descDE: "Lizenz für Ultraleichtflugzeuge", descEN: "Ultralight aircraft licence" },
  { value: "Paramotor", icon: "🏔️", labelDE: "Paramotor", labelEN: "Paramotor",
    descDE: "Motorisiertes Gleitschirmfliegen", descEN: "Motorised paragliding" },
  { value: "Other", icon: "⭐", labelDE: "Sonstige Lizenz", labelEN: "Other Licence",
    descDE: "Andere Pilotenlizenz oder Berechtigung", descEN: "Other pilot licence or rating" },
  { value: "None", icon: "➖", labelDE: "Keine Fluglizenz", labelEN: "No Flight Licence",
    descDE: "Noch keine Flugerfahrung als Pilot/in", descEN: "No flying experience as pilot yet" },
];

export default function LicensesPage() {
  const { isGerman, updateFlightLicenses } = useAuth();
  const router = useRouter();
  const [selected, setSelected] = useState<FlightLicense[]>([]);
  const [saving, setSaving] = useState(false);

  function toggle(v: FlightLicense) {
    if (v === "None") {
      setSelected(selected.includes("None") ? [] : ["None"]);
      return;
    }
    setSelected((prev) => {
      const without = prev.filter((x) => x !== "None");
      return without.includes(v) ? without.filter((x) => x !== v) : [...without, v];
    });
  }

  async function proceed() {
    if (selected.length === 0) return;
    setSaving(true);
    await updateFlightLicenses(selected);
    router.replace("/dashboard");
  }

  return (
    <div className="min-h-svh px-5 py-10 space-y-6" style={{ background: "var(--app-bg)" }}>
      <div className="space-y-2">
        <h1 className="text-2xl font-bold" style={{ color: "var(--app-primary)" }}>
          {isGerman ? "Welche Lizenzen besitzt du?" : "Which licences do you hold?"}
        </h1>
        <p className="text-sm" style={{ color: "var(--app-secondary)" }}>
          {isGerman ? "Mehrfachauswahl möglich. Beeinflusst die Fragen im Self-Assessment." : "Multiple selection allowed. Influences self-assessment questions."}
        </p>
      </div>

      <div className="space-y-3">
        {LICENSES.map(({ value, icon, labelDE, labelEN, descDE, descEN }) => {
          const isOn = selected.includes(value);
          return (
            <button key={value} onClick={() => toggle(value)}
              className="w-full text-left p-4 rounded-2xl transition-all"
              style={{
                background: isOn ? "rgba(74,158,248,0.12)" : "var(--app-card)",
                border: `1px solid ${isOn ? "rgba(74,158,248,0.5)" : "var(--app-border)"}`,
              }}>
              <div className="flex items-center gap-3">
                <span className="text-2xl">{icon}</span>
                <div className="flex-1">
                  <div className="font-semibold text-sm" style={{ color: "var(--app-primary)" }}>
                    {isGerman ? labelDE : labelEN}
                  </div>
                  <div className="text-xs mt-0.5" style={{ color: "var(--app-secondary)" }}>
                    {isGerman ? descDE : descEN}
                  </div>
                </div>
                <div className="w-5 h-5 rounded-md flex items-center justify-center"
                  style={{ background: isOn ? "#4A9EF8" : "transparent", border: `2px solid ${isOn ? "#4A9EF8" : "var(--app-border)"}` }}>
                  {isOn && <span className="text-white text-xs font-bold">✓</span>}
                </div>
              </div>
            </button>
          );
        })}
      </div>

      <button className="btn-primary" disabled={selected.length === 0 || saving} onClick={proceed}>
        {saving ? <div className="spinner" /> : (isGerman ? "Weiter" : "Continue")}
      </button>
    </div>
  );
}
