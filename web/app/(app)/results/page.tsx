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
        <div className="flex items-center px-4 gap-2"
          style={{ paddingTop: "max(env(safe-area-inset-top, 12px), 12px)", paddingBottom: 8 }}>
          <button onClick={() => router.back()}
            className="w-8 h-8 flex items-center justify-center rounded-full"
            style={{ background: "var(--app-input)" }}>
            <ChevronLeftSVG />
          </button>
          <h1 className="flex-1 text-center font-bold text-base" style={{ color: "var(--app-primary)" }}>
            {t("Dein Report","Your Report",isGerman)}
          </h1>
          <button onClick={exportReport}
            className="w-8 h-8 flex items-center justify-center rounded-full"
            style={{ background: "var(--app-input)" }}>
            <ShareUpSVG />
          </button>
        </div>
        {/* Segmented control */}
        <div className="flex mx-4 mb-2 p-1 rounded-xl" style={{ background: "var(--app-input)" }}>
          {tabs.map((label, i) => (
            <button key={i} onClick={() => setTab(i)}
              className="flex-1 py-1.5 rounded-lg text-xs font-semibold transition-all"
              style={{
                background: tab === i ? "var(--app-card)" : "transparent",
                color: tab === i ? "var(--app-primary)" : "var(--app-tertiary)",
                boxShadow: tab === i ? "0 1px 4px rgba(0,0,0,0.25)" : "none",
              }}>
              {label}
            </button>
          ))}
        </div>
      </div>

      <div className="px-4 py-4 space-y-4 pb-safe">
        {tab === 0 && <ProfileTab result={result} isGerman={isGerman} />}
        {tab === 1 && (
          <ComparisonTab result={result} isGerman={isGerman}
            filterRel={filterRel} setFilterRel={setFilterRel}
            filteredData={filteredData} filterLoading={filterLoading} />
        )}
        {tab === 2 && (
          <RawDataTab result={result} isGerman={isGerman}
            filterRel={filterRel} setFilterRel={setFilterRel}
            filteredData={filteredData} filterLoading={filterLoading} />
        )}
      </div>
    </div>
  );

  function exportReport() {
    if (!result) return;
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
  const traits = result.traitStats.filter(s => s.othersPercent > 0.2 || s.selfSelected);
  return (
    <>
      {/* Das macht dich aus */}
      <SectionCard
        title={t("Das macht dich aus","What defines you",isGerman)}
        iconBg="rgba(74,158,248,0.2)"
        icon={<PersonFillSVG size={20} color="#4A9EF8" />}>
        {traits.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {traits.slice(0, 8).map(s => (
              <div key={s.id} className="flex items-center gap-1.5 px-3 py-1.5 rounded-full"
                style={{ background: "var(--app-input)" }}>
                <span className="font-bold text-sm" style={{ color: "var(--app-primary)" }}>{s.name}</span>
                {s.othersPercent > 0 && (
                  <span className="text-xs" style={{ color: "var(--app-tertiary)" }}>
                    {Math.round(s.othersPercent * 100)}%
                  </span>
                )}
              </div>
            ))}
          </div>
        )}
        <Divider />
        <p className="text-sm leading-relaxed" style={{ color: "var(--app-secondary)" }}>
          {result.personalitySummary}
        </p>
        <p className="text-xs mt-1" style={{ color: "var(--app-tertiary)" }}>
          {t("Basierend auf","Based on",isGerman)} {result.respondentCount} {t("Antworten","responses",isGerman)}
        </p>
      </SectionCard>

      {/* Stärken */}
      <SectionCard
        title={t("Deine Stärken","Your Strengths",isGerman)}
        iconBg="rgba(52,199,89,0.2)"
        icon={<StarSVG size={20} color="#34C759" />}>
        <div className="space-y-3">
          {result.perceivedStrengths.map((s, i) => <StrengthRow key={i} text={s} />)}
        </div>
      </SectionCard>

      {/* Schwächen */}
      <SectionCard
        title={t("Deine Schwächen","Areas to Develop",isGerman)}
        iconBg="rgba(255,159,10,0.2)"
        icon={<WarningSVG size={20} color="#FF9F0A" />}>
        <div className="space-y-3">
          {result.possibleWeaknesses.map((s, i) => <WeaknessRow key={i} text={s} />)}
        </div>
      </SectionCard>

      {/* Empfehlung */}
      <SectionCard
        title={t("Empfehlung für dein Assessment","Recommendation for your Assessment",isGerman)}
        iconBg="rgba(107,94,228,0.2)"
        icon={<SparklesSVG size={20} color="#6B5EE4" />}>
        <p className="text-sm leading-relaxed" style={{ color: "var(--app-secondary)" }}>
          {result.assessmentAdvice}
        </p>
        {result.selfAwarenessTips.length > 0 && (
          <>
            <Divider />
            <div className="flex items-start gap-2">
              <span className="text-base flex-shrink-0 leading-tight">💡</span>
              <p className="text-xs leading-relaxed" style={{ color: "var(--app-secondary)" }}>
                {result.selfAwarenessTips[0]}
              </p>
            </div>
          </>
        )}
        {result.interviewTips.length > 0 && (
          <>
            <Divider />
            <p className="text-[10px] font-bold uppercase tracking-wider mb-3"
              style={{ color: "#4A9EF8" }}>
              {t("Mögliche Fragen","Possible Questions",isGerman)}
            </p>
            <div className="space-y-3">
              {result.interviewTips.map((tip, i) => <QuestionRow key={i} text={tip} />)}
            </div>
          </>
        )}
      </SectionCard>

      {/* Unterstützer */}
      {(result.motivationWishes?.length ?? 0) > 0 && (
        <SectionCard
          title={t("Deine Unterstützer","Your Supporters",isGerman)}
          iconBg="rgba(255,107,107,0.2)"
          icon={<HeartSVG size={20} color="#FF6B6B" />}>
          {(result.motivationConfidenceAvg ?? 0) > 0 && (
            <>
              <div className="flex items-center justify-between">
                <p className="font-bold text-sm" style={{ color: "var(--app-primary)" }}>
                  {result.motivationConfidenceCount} {t("Personen glauben an dich","people believe in you",isGerman)}
                </p>
                <span className="font-bold text-sm" style={{ color: "#FF6B6B" }}>
                  {result.motivationConfidenceAvg!.toFixed(1)} / 5
                </span>
              </div>
              <div className="h-2.5 rounded-full overflow-hidden" style={{ background: "var(--app-input)" }}>
                <div className="h-full rounded-full transition-all"
                  style={{ width: `${(result.motivationConfidenceAvg! / 5) * 100}%`, background: "#FF6B6B" }} />
              </div>
              <p className="text-xs" style={{ color: "var(--app-tertiary)" }}>
                {t("Durchschnittliche Zuversicht deiner Unterstützer","Average confidence of your supporters",isGerman)}
              </p>
              <Divider />
            </>
          )}
          <p className="text-[10px] font-bold uppercase tracking-wider mb-2"
            style={{ color: "var(--app-tertiary)" }}>
            {t("Persönliche Wünsche","Personal Messages",isGerman)}
          </p>
          <div className="space-y-2">
            {result.motivationWishes!.map((w, i) => (
              <div key={i} className="px-3 py-2.5 rounded-xl"
                style={{ background: "var(--app-input)" }}>
                <p className="text-sm italic" style={{ color: "var(--app-secondary)" }}>{w}</p>
              </div>
            ))}
          </div>
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
          <SectionCard
            title={t("Du vs. Andere","You vs. Others",isGerman)}
            iconBg="rgba(74,158,248,0.2)"
            icon={<ChartBarSVG size={20} color="#4A9EF8" />}>
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
            <SectionCard
              title={t("Entscheidungsstil","Decision Style",isGerman)}
              iconBg="rgba(107,94,228,0.2)"
              icon={<ShuffleSVG size={20} color="#6B5EE4" />}>
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
        <SectionCard
          title={t("Freitext-Antworten","Open Text Responses",isGerman)}
          iconBg="rgba(74,158,248,0.15)"
          icon={<ChatSVG size={20} color="#4A9EF8" />}>
          {texts.length === 0 ? (
            <p className="text-sm" style={{ color: "var(--app-tertiary)" }}>
              {t("Keine Antworten vorhanden.","No responses available.",isGerman)}
            </p>
          ) : (
            <div className="space-y-2">
              {texts.map((text, i) => (
                <div key={i} className="p-3 rounded-xl text-sm"
                  style={{ background: "var(--app-input)", color: "var(--app-secondary)" }}>
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

function SectionCard({ title, iconBg, icon, children }: {
  title: string; iconBg: string; icon: React.ReactNode; children: React.ReactNode;
}) {
  return (
    <div className="rounded-2xl p-5 space-y-3"
      style={{ background: "var(--app-card)", border: "1px solid var(--app-border)" }}>
      <div className="flex items-center gap-3">
        <div className="rounded-xl flex items-center justify-center flex-shrink-0"
          style={{ width: 40, height: 40, background: iconBg }}>
          {icon}
        </div>
        <h3 className="font-bold text-base" style={{ color: "var(--app-primary)" }}>{title}</h3>
      </div>
      {children}
    </div>
  );
}

function Divider() {
  return <div style={{ height: 1, background: "var(--app-border)", margin: "2px 0" }} />;
}

function StrengthRow({ text }: { text: string }) {
  const [dim, desc] = text.includes(": ") ? text.split(": ") : [null, text];
  return (
    <div className="flex items-start gap-3">
      <div className="w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5"
        style={{ background: "#34C759" }}>
        <CheckSVG size={11} color="white" strokeWidth={3} />
      </div>
      <p className="text-sm flex-1 leading-snug" style={{ color: "var(--app-secondary)" }}>
        {dim && <strong style={{ color: "var(--app-primary)" }}>{dim}: </strong>}{desc}
      </p>
    </div>
  );
}

function WeaknessRow({ text }: { text: string }) {
  const [dim, desc] = text.includes(": ") ? text.split(": ") : [null, text];
  return (
    <div className="flex items-start gap-3">
      <div className="flex items-center justify-center flex-shrink-0 mt-0.5" style={{ width: 24, height: 24 }}>
        <RefreshCWSVG size={22} color="#FF9F0A" />
      </div>
      <p className="text-sm flex-1 leading-snug" style={{ color: "var(--app-secondary)" }}>
        {dim && <strong style={{ color: "var(--app-primary)" }}>{dim}: </strong>}{desc}
      </p>
    </div>
  );
}

function QuestionRow({ text }: { text: string }) {
  return (
    <div className="flex items-start gap-3">
      <div className="w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5 text-xs font-bold"
        style={{ background: "rgba(107,94,228,0.25)", color: "#6B5EE4", minWidth: 24 }}>
        ?
      </div>
      <p className="text-sm flex-1 leading-snug" style={{ color: "var(--app-secondary)" }}>{text}</p>
    </div>
  );
}

// ─── SVG Icons ────────────────────────────────────────────────────────────────

function CheckSVG({ size = 14, color = "white", strokeWidth = 2.5 }: { size?: number; color?: string; strokeWidth?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  );
}

function ChevronLeftSVG() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--app-secondary)"
      strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="15 18 9 12 15 6" />
    </svg>
  );
}

function ShareUpSVG() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--app-secondary)"
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 12v8a2 2 0 002 2h12a2 2 0 002-2v-8"/>
      <polyline points="16 6 12 2 8 6"/>
      <line x1="12" y1="2" x2="12" y2="15"/>
    </svg>
  );
}

function PersonFillSVG({ size = 20, color = "#4A9EF8" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
    </svg>
  );
}

function StarSVG({ size = 20, color = "#34C759" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
    </svg>
  );
}

function WarningSVG({ size = 20, color = "#FF9F0A" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
      <line x1="12" y1="9" x2="12" y2="13"/>
      <line x1="12" y1="17" x2="12.01" y2="17"/>
    </svg>
  );
}

function SparklesSVG({ size = 20, color = "#6B5EE4" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3l1.5 4.5L18 9l-4.5 1.5L12 15l-1.5-4.5L6 9l4.5-1.5L12 3z"/>
      <path d="M19 14l.75 2.25L22 17l-2.25.75L19 20l-.75-2.25L16 17l2.25-.75L19 14z"/>
      <path d="M5 18l.5 1.5L7 20l-1.5.5L5 22l-.5-1.5L3 20l1.5-.5L5 18z"/>
    </svg>
  );
}

function HeartSVG({ size = 20, color = "#FF6B6B" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z"/>
    </svg>
  );
}

function RefreshCWSVG({ size = 20, color = "#FF9F0A" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="23 4 23 10 17 10"/>
      <path d="M20.49 15a9 9 0 11-2.12-9.36L23 10"/>
    </svg>
  );
}

function ChartBarSVG({ size = 20, color = "#4A9EF8" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <line x1="18" y1="20" x2="18" y2="10"/>
      <line x1="12" y1="20" x2="12" y2="4"/>
      <line x1="6" y1="20" x2="6" y2="14"/>
    </svg>
  );
}

function ShuffleSVG({ size = 20, color = "#6B5EE4" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="16 3 21 3 21 8"/>
      <line x1="4" y1="20" x2="21" y2="3"/>
      <polyline points="21 16 21 21 16 21"/>
      <line x1="15" y1="15" x2="21" y2="21"/>
      <line x1="4" y1="4" x2="9" y2="9"/>
    </svg>
  );
}

function ChatSVG({ size = 20, color = "#4A9EF8" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/>
    </svg>
  );
}
