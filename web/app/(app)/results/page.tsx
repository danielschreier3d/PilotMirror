"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { supabase } from "@/lib/supabase";
import type { AnalysisResult, ComparisonArea, ForcedChoiceStat, RelationshipType } from "@/lib/types";
import { RELATIONSHIP_LABELS } from "@/lib/types";

function t(de: string, en: string, g: boolean) { return g ? de : en; }

interface FilteredData {
  texts: string[];
  comparison: ComparisonArea[];
  count: number;
}

function gapLabel(d: number, g: boolean): string {
  const abs = Math.abs(d);
  if (abs < 0.3) return g ? "Realistische Einschätzung" : "Realistic self-assessment";
  if (d >= 0.7)  return g ? "Du überschätzt dich deutlich" : "Significant overestimation";
  if (d >= 0.3)  return g ? "Du schätzt dich leicht höher ein" : "Slight overestimation";
  if (d <= -0.7) return g ? "Andere sehen dich deutlich stärker" : "Others see you as clearly stronger";
  return g ? "Andere sehen dich leicht stärker" : "Others see you slightly stronger";
}

function gapColor(d: number): string {
  const abs = Math.abs(d);
  if (abs < 0.3) return "#4A9EF8";
  if (abs < 0.7) return "#FF9F0A";
  return d > 0 ? "#FF6B6B" : "#34C759";
}

export default function ResultsPage() {
  const { isGerman } = useAuth();
  const router = useRouter();
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [tab, setTab] = useState(0);
  const [filterRel, setFilterRel]       = useState<RelationshipType | "all">("all");
  const [filteredData, setFilteredData] = useState<FilteredData | null>(null);
  const [filterLoading, setFilterLoading] = useState(false);

  useEffect(() => {
    const cached = localStorage.getItem("pm_analysis_result_v1");
    if (cached) { try { setResult(JSON.parse(cached)); } catch { /* */ } }
  }, []);

  useEffect(() => {
    if (filterRel === "all" || !result) { setFilteredData(null); return; }
    setFilterLoading(true);
    (async () => {
      try {
        const sessionId = localStorage.getItem("pm_session_id");
        if (!sessionId) return;
        const { data: link } = await supabase.from("feedback_links").select("id").eq("session_id", sessionId).single();
        if (!link) { setFilteredData({ texts: [], comparison: [], count: 0 }); return; }
        const { data: respondents } = await supabase.from("respondents").select("id").eq("feedback_link_id", link.id).eq("relationship", filterRel);
        if (!respondents?.length) { setFilteredData({ texts: [], comparison: [], count: 0 }); return; }
        const ids = (respondents as { id: string }[]).map(r => r.id);
        const { data: responses } = await supabase.from("survey_responses").select("question_id, answer_type, answer_value").in("respondent_id", ids);
        const ratingMap: Record<string, number[]> = {};
        const textList: string[] = [];
        for (const r of (responses ?? []) as { question_id: string; answer_type: string; answer_value: string }[]) {
          if (r.answer_type === "rating") {
            const n = parseInt(r.answer_value, 10);
            if (!isNaN(n)) { ratingMap[r.question_id] = [...(ratingMap[r.question_id] ?? []), n]; }
          } else if (r.answer_type === "text" && r.answer_value) {
            textList.push(r.answer_value);
          }
        }
        const filteredComparison = result.comparisonAreas
          .map(area => { const rs = ratingMap[area.id] ?? []; if (!rs.length) return null; return { ...area, othersAverage: rs.reduce((a, b) => a + b, 0) / rs.length }; })
          .filter(Boolean) as ComparisonArea[];
        setFilteredData({ texts: textList, comparison: filteredComparison, count: respondents.length });
      } finally { setFilterLoading(false); }
    })();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filterRel, result]);

  if (!result) {
    return (
      <div className="flex items-center justify-center min-h-svh" style={{ background: "var(--app-bg)" }}>
        <div className="text-center space-y-3">
          <div className="spinner mx-auto" />
          <p className="text-sm" style={{ color: "var(--app-secondary)" }}>
            {t("Analyse wird erstellt…","Generating analysis…",isGerman)}
          </p>
        </div>
      </div>
    );
  }

  const tabs = [
    t("Profil","Profile",isGerman),
    t("Vergleich","Comparison",isGerman),
    t("Rohdaten","Raw Data",isGerman),
  ];

  return (
    <div className="min-h-svh" style={{ background: "var(--app-bg)" }}>
      {/* Nav bar */}
      <div className="sticky top-0 z-40" style={{ background: "var(--app-bg)", borderBottom: "1px solid var(--app-border)" }}>
        <div className="flex items-center px-4 gap-2" style={{ paddingTop: "max(env(safe-area-inset-top, 12px), 12px)", paddingBottom: 8 }}>
          <button onClick={() => router.back()} className="w-8 h-8 flex items-center justify-center rounded-full text-sm"
            style={{ background: "var(--app-input)" }}>←</button>
          <h1 className="flex-1 text-center font-bold text-base" style={{ color: "var(--app-primary)" }}>
            {t("Dein Report","Your Report",isGerman)}
          </h1>
          <button onClick={exportReport} className="w-8 h-8 flex items-center justify-center rounded-full text-sm"
            style={{ background: "var(--app-input)" }}>⬆️</button>
        </div>
        {/* Tabs */}
        <div className="flex px-4 pb-2 gap-1">
          {tabs.map((label, i) => (
            <button key={i} onClick={() => setTab(i)}
              className="flex-1 py-2 rounded-xl text-xs font-semibold transition-all"
              style={{
                background: tab === i ? "#4A9EF8" : "var(--app-input)",
                color: tab === i ? "white" : "var(--app-secondary)",
              }}>
              {label}
            </button>
          ))}
        </div>
      </div>

      <div className="px-4 py-4 space-y-4 pb-safe">
        {tab === 0 && <ProfileTab result={result} isGerman={isGerman} />}
        {tab === 1 && <ComparisonTab result={result} isGerman={isGerman} filterRel={filterRel} setFilterRel={setFilterRel} filteredData={filteredData} filterLoading={filterLoading} />}
        {tab === 2 && <RawDataTab result={result} isGerman={isGerman} filterRel={filterRel} setFilterRel={setFilterRel} filteredData={filteredData} filterLoading={filterLoading} />}
      </div>
    </div>
  );

  function exportReport() {
    const lines = [
      "# PilotMirror 360° Report",
      "",
      `## ${t("Profil","Profile",isGerman)}`,
      result.personalitySummary,
      "",
      `### ${t("Stärken","Strengths",isGerman)}`,
      ...result.perceivedStrengths.map((s) => `• ${s}`),
      "",
      `### ${t("Entwicklungsfelder","Development Areas",isGerman)}`,
      ...result.possibleWeaknesses.map((s) => `• ${s}`),
      "",
      `### ${t("Selbst- vs. Fremdwahrnehmung","Self vs. Others",isGerman)}`,
      result.selfVsOthers,
      "",
      `### ${t("Empfehlung","Recommendation",isGerman)}`,
      result.assessmentAdvice,
    ].join("\n");
    const blob = new Blob([lines], { type: "text/plain" });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement("a");
    a.href = url; a.download = "PilotMirror_Report.txt"; a.click();
    URL.revokeObjectURL(url);
  }
}

// ─── Tab: Profile ─────────────────────────────────────────────────────────────

function ProfileTab({ result, isGerman }: { result: AnalysisResult; isGerman: boolean }) {
  return (
    <>
      {/* Personality summary */}
      <SectionCard title={t("Persönlichkeitsprofil","Personality Profile",isGerman)} icon="🪞">
        <p className="text-sm leading-relaxed" style={{ color: "var(--app-secondary)" }}>
          {result.personalitySummary}
        </p>
        <div className="flex items-center gap-2 mt-3 text-xs" style={{ color: "var(--app-tertiary)" }}>
          <span>{t("Basierend auf","Based on",isGerman)} {result.respondentCount} {t("Antworten","responses",isGerman)}</span>
        </div>
      </SectionCard>

      {/* Traits */}
      {result.traitStats.length > 0 && (
        <SectionCard title={t("Charaktereigenschaften","Character Traits",isGerman)} icon="✨">
          <div className="flow-wrap">
            {result.traitStats.filter((s) => s.othersPercent > 0.2 || s.selfSelected).map((s) => (
              <div key={s.id} className="px-3 py-1.5 rounded-full text-xs font-medium"
                style={{
                  background: s.selfSelected && s.othersPercent > 0.2 ? "#4A9EF8" :
                              s.selfSelected ? "rgba(74,158,248,0.3)" :
                              "var(--app-input)",
                  color: s.selfSelected && s.othersPercent > 0.2 ? "white" : "var(--app-primary)",
                }}>
                {s.name} {s.othersPercent > 0 && `${Math.round(s.othersPercent * 100)}%`}
              </div>
            ))}
          </div>
        </SectionCard>
      )}

      {/* Strengths */}
      <SectionCard title={t("Stärken","Strengths",isGerman)} icon="💪" accentColor="#34C759">
        {result.perceivedStrengths.map((s, i) => <BulletRow key={i} text={s} color="#34C759" />)}
      </SectionCard>

      {/* Weaknesses */}
      <SectionCard title={t("Entwicklungsfelder","Development Areas",isGerman)} icon="🔧" accentColor="#FF9F0A">
        {result.possibleWeaknesses.map((s, i) => <BulletRow key={i} text={s} color="#FF9F0A" />)}
      </SectionCard>

      {/* Self vs Others */}
      <SectionCard title={t("Selbst- vs. Fremdwahrnehmung","Self vs. Others",isGerman)} icon="⚖️">
        <p className="text-sm leading-relaxed" style={{ color: "var(--app-secondary)" }}>
          {result.selfVsOthers}
        </p>
      </SectionCard>

      {/* Assessment advice */}
      <SectionCard title={t("Assessment-Empfehlung","Assessment Advice",isGerman)} icon="🎯" accentColor="#4A9EF8">
        <p className="text-sm leading-relaxed" style={{ color: "var(--app-secondary)" }}>
          {result.assessmentAdvice}
        </p>
      </SectionCard>

      {/* Motivation */}
      {(result.motivationWishes?.length ?? 0) > 0 && (
        <SectionCard title={t("Wünsche","Messages",isGerman)} icon="💌">
          <div className="space-y-2">
            {result.motivationWishes!.map((w, i) => (
              <div key={i} className="p-3 rounded-xl text-sm italic" style={{ background: "var(--app-input)", color: "var(--app-secondary)" }}>
                &ldquo;{w}&rdquo;
              </div>
            ))}
          </div>
          {(result.motivationConfidenceAvg ?? 0) > 0 && (
            <p className="text-xs mt-3" style={{ color: "var(--app-tertiary)" }}>
              {t("Vertrauen","Confidence",isGerman)}: {result.motivationConfidenceAvg!.toFixed(1)}/5
              ({result.motivationConfidenceCount} {t("Bewertungen","ratings",isGerman)})
            </p>
          )}
        </SectionCard>
      )}
    </>
  );
}

// ─── Tab: Comparison ──────────────────────────────────────────────────────────

function ComparisonTab({ result, isGerman, filterRel, setFilterRel, filteredData, filterLoading }: {
  result: AnalysisResult; isGerman: boolean;
  filterRel: RelationshipType | "all"; setFilterRel: (r: RelationshipType | "all") => void;
  filteredData: FilteredData | null; filterLoading: boolean;
}) {
  const areas = filterRel === "all" ? result.comparisonAreas : (filteredData?.comparison ?? []);
  return (
    <>
      <RelFilterChips filterRel={filterRel} setFilterRel={setFilterRel} isGerman={isGerman} />
      {filterLoading ? (
        <div className="flex justify-center py-8"><div className="spinner" /></div>
      ) : (
        <>
          {filterRel !== "all" && filteredData && (
            <p className="text-xs text-center" style={{ color: "var(--app-tertiary)" }}>
              {filteredData.count} {t("Antworten von dieser Gruppe","responses from this group",isGerman)}
            </p>
          )}
          <SectionCard title={t("Du vs. Andere","You vs. Others",isGerman)} icon="📊">
            {areas.length === 0 ? (
              <p className="text-sm" style={{ color: "var(--app-tertiary)" }}>
                {t("Keine Daten für diese Gruppe.","No data for this group.",isGerman)}
              </p>
            ) : (
              <div className="space-y-4">
                {areas.map((area) => (
                  <ComparisonRow key={area.id} area={area} isGerman={isGerman} />
                ))}
              </div>
            )}
          </SectionCard>
          {filterRel === "all" && result.forcedChoiceStats.length > 0 && (
            <SectionCard title={t("Entscheidungsstil","Decision Style",isGerman)} icon="🔀">
              <div className="space-y-5">
                {result.forcedChoiceStats.map((stat) => (
                  <ForcedChoiceRow key={stat.id} stat={stat} isGerman={isGerman} />
                ))}
              </div>
            </SectionCard>
          )}
        </>
      )}
    </>
  );
}

function ComparisonRow({ area, isGerman }: { area: ComparisonArea; isGerman: boolean }) {
  const diff  = area.selfRating - area.othersAverage;
  const label = gapLabel(diff, isGerman);
  const color = gapColor(diff);
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between items-center">
        <span className="text-sm font-semibold" style={{ color: "var(--app-primary)" }}>{area.name}</span>
        <span className="text-xs px-2 py-0.5 rounded-full font-semibold"
          style={{ background: `${color}20`, color }}>{label}</span>
      </div>
      <div className="flex items-center gap-3 text-xs" style={{ color: "var(--app-secondary)" }}>
        <span>{isGerman ? "Du" : "You"}: <strong style={{ color: "#4A9EF8" }}>{area.selfRating.toFixed(1)}</strong></span>
        <span>{isGerman ? "Andere" : "Others"}: <strong style={{ color: "var(--app-primary)" }}>{area.othersAverage.toFixed(2)}</strong></span>
      </div>
      {/* Visual bar */}
      <div className="flex items-center gap-2">
        <div className="flex-1 h-1.5 rounded-full overflow-hidden" style={{ background: "var(--app-input)" }}>
          <div className="h-full rounded-full" style={{ width: `${(area.selfRating / 5) * 100}%`, background: "#4A9EF8" }} />
        </div>
        <div className="flex-1 h-1.5 rounded-full overflow-hidden" style={{ background: "var(--app-input)" }}>
          <div className="h-full rounded-full" style={{ width: `${(area.othersAverage / 5) * 100}%`, background: "var(--app-secondary)" }} />
        </div>
      </div>
    </div>
  );
}

function ForcedChoiceRow({ stat, isGerman }: { stat: ForcedChoiceStat; isGerman: boolean }) {
  const sorted = Object.entries(stat.results).sort((a, b) => b[1] - a[1]);
  return (
    <div className="space-y-2">
      <p className="text-sm font-semibold" style={{ color: "var(--app-primary)" }}>{stat.question}</p>
      {sorted.map(([option, pct]) => {
        const isSelf = option === stat.selfChoice;
        return (
          <div key={option} className="space-y-1">
            <div className="flex justify-between text-xs" style={{ color: isSelf ? "#4A9EF8" : "var(--app-secondary)" }}>
              <span>{option}{isSelf ? ` (${isGerman ? "du" : "you"})` : ""}</span>
              <span>{Math.round(pct * 100)}%</span>
            </div>
            <div className="h-1.5 rounded-full overflow-hidden" style={{ background: "var(--app-input)" }}>
              <div className="h-full rounded-full transition-all"
                style={{ width: `${pct * 100}%`, background: isSelf ? "#4A9EF8" : "var(--app-secondary)" }} />
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ─── Tab: Raw Data ────────────────────────────────────────────────────────────

function RawDataTab({ result, isGerman, filterRel, setFilterRel, filteredData, filterLoading }: {
  result: AnalysisResult; isGerman: boolean;
  filterRel: RelationshipType | "all"; setFilterRel: (r: RelationshipType | "all") => void;
  filteredData: FilteredData | null; filterLoading: boolean;
}) {
  const texts = filterRel === "all" ? result.openTextResponses : (filteredData?.texts ?? []);
  return (
    <>
      <RelFilterChips filterRel={filterRel} setFilterRel={setFilterRel} isGerman={isGerman} />
      {filterLoading ? (
        <div className="flex justify-center py-8"><div className="spinner" /></div>
      ) : (
        <SectionCard title={t("Freitext-Antworten","Open Text Responses",isGerman)} icon="💬">
          {texts.length === 0 ? (
            <p className="text-sm" style={{ color: "var(--app-tertiary)" }}>
              {t("Keine Antworten vorhanden.","No responses available.",isGerman)}
            </p>
          ) : (
            <div className="space-y-2">
              {texts.map((text, i) => (
                <div key={i} className="p-3 rounded-xl text-sm" style={{ background: "var(--app-input)", color: "var(--app-secondary)" }}>
                  {text}
                </div>
              ))}
            </div>
          )}
        </SectionCard>
      )}
    </>
  );
}

// ─── Shared components ────────────────────────────────────────────────────────

function RelFilterChips({ filterRel, setFilterRel, isGerman }: {
  filterRel: RelationshipType | "all";
  setFilterRel: (r: RelationshipType | "all") => void;
  isGerman: boolean;
}) {
  return (
    <div className="flex gap-2 overflow-x-auto pb-1 -mx-1 px-1">
      <button onClick={() => setFilterRel("all")}
        className="py-1.5 px-3 rounded-full text-xs font-semibold flex-shrink-0"
        style={{ background: filterRel === "all" ? "#4A9EF8" : "var(--app-input)", color: filterRel === "all" ? "white" : "var(--app-secondary)" }}>
        {isGerman ? "Alle" : "All"}
      </button>
      {(Object.entries(RELATIONSHIP_LABELS) as [RelationshipType, { de: string; en: string }][]).map(([rel, labels]) => (
        <button key={rel} onClick={() => setFilterRel(rel)}
          className="py-1.5 px-3 rounded-full text-xs font-semibold flex-shrink-0"
          style={{ background: filterRel === rel ? "#4A9EF8" : "var(--app-input)", color: filterRel === rel ? "white" : "var(--app-secondary)" }}>
          {isGerman ? labels.de : labels.en}
        </button>
      ))}
    </div>
  );
}

function SectionCard({ title, icon, accentColor, children }: {
  title: string; icon: string; accentColor?: string; children: React.ReactNode;
}) {
  return (
    <div className="rounded-2xl p-5 space-y-3"
      style={{ background: "var(--app-card)", border: "1px solid var(--app-border)" }}>
      <div className="flex items-center gap-2">
        <span className="text-lg">{icon}</span>
        <h3 className="font-bold text-sm" style={{ color: accentColor ?? "var(--app-primary)" }}>{title}</h3>
      </div>
      {children}
    </div>
  );
}

function BulletRow({ text, color }: { text: string; color: string }) {
  const [dim, desc] = text.includes(": ") ? text.split(": ") : [null, text];
  return (
    <div className="flex items-start gap-2">
      <div className="w-1.5 h-1.5 rounded-full mt-2 flex-shrink-0" style={{ background: color }} />
      <p className="text-sm flex-1" style={{ color: "var(--app-secondary)", lineHeight: 1.5 }}>
        {dim && <strong style={{ color: "var(--app-primary)" }}>{dim}: </strong>}{desc}
      </p>
    </div>
  );
}
