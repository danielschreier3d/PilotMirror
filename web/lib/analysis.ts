import { supabase, ANALYZE_URL, SUPABASE_ANON } from "./supabase";
import { SURVEY_QUESTIONS } from "./questions";
import type { AnalysisResult, ComparisonArea, TraitStat, ForcedChoiceStat, AnswerValue, FlightLicense } from "./types";

// ─── Load responses from Supabase ────────────────────────────────────────────

export async function loadSelfResponses(sessionId: string): Promise<Record<string, AnswerValue>> {
  const { data } = await supabase
    .from("self_responses")
    .select("*")
    .eq("session_id", sessionId);
  if (!data) return {};
  const out: Record<string, AnswerValue> = {};
  for (const row of data) {
    const ans = rowToAnswerValue(row.answer_type as string, row.answer_value as string);
    if (ans) out[row.question_id as string] = ans;
  }
  return out;
}

export async function loadRespondentResponses(linkId: string): Promise<Record<string, AnswerValue>[]> {
  const { data } = await supabase.rpc("get_all_respondent_data", { p_link_id: linkId });
  if (!data) return [];
  const byRespondent: Record<string, Record<string, AnswerValue>> = {};
  for (const row of data as Array<{respondent_id:string;question_id:string;answer_type:string;answer_value:string}>) {
    const ans = rowToAnswerValue(row.answer_type, row.answer_value);
    if (ans) {
      if (!byRespondent[row.respondent_id]) byRespondent[row.respondent_id] = {};
      byRespondent[row.respondent_id][row.question_id] = ans;
    }
  }
  return Object.values(byRespondent).filter((r) => Object.keys(r).length > 0);
}

function rowToAnswerValue(type: string, value: string): AnswerValue | null {
  switch (type) {
    case "single":   return { type: "singleChoice", value };
    case "multiple": try { return { type: "multipleChoice", value: JSON.parse(value) }; } catch { return null; }
    case "rating":   { const n = parseInt(value, 10); return isNaN(n) ? null : { type: "rating", value: n }; }
    case "text":     return { type: "text", value };
    default:         return null;
  }
}

// ─── Build prompt ─────────────────────────────────────────────────────────────

export function buildPrompt(
  assessmentType: string,
  selfResponses: Record<string, AnswerValue>,
  externalResponses: Record<string, AnswerValue>[],
  flightLicenses: FlightLicense[] = []
): string {
  const questions = SURVEY_QUESTIONS;
  const n = externalResponses.length;

  function formatAnswerValue(a: AnswerValue): string {
    if (a.type === "multipleChoice") return a.value.join(", ");
    if (a.type === "singleChoice")   return a.value;
    if (a.type === "rating")         return String(a.value);
    if (a.type === "text")           return a.value;
    return "";
  }

  function format(responses: Record<string, AnswerValue>): string {
    return questions.flatMap((q) => {
      const a = responses[q.id];
      if (!a) return [];
      const text = formatAnswerValue(a).trim();
      if (q.type === "openText" && text.length < 3) return [];
      return [`- ${q.text}: ${text}`];
    }).join("\n");
  }

  // Rating comparison data
  const ratingDimensions = [
    {id:"q5",name:"Teamwork"},{id:"q6",name:"Stressresistenz"},{id:"q7",name:"Verantwortung"},
    {id:"q8",name:"Kommunikation"},{id:"q9",name:"Zuverlässigkeit"},{id:"q10_org",name:"Struktur/Organisation"},
  ];
  const ratingsBlock = ratingDimensions.flatMap((dim) => {
    const selfA = selfResponses[dim.id];
    if (!selfA || selfA.type !== "rating") return [];
    const selfVal = selfA.value;
    const otherVals = externalResponses.flatMap((r) => {
      const a = r[dim.id];
      return (a?.type === "rating") ? [a.value] : [];
    });
    if (otherVals.length === 0) return [];
    const avg = otherVals.reduce((s, v) => s + v, 0) / otherVals.length;
    const delta = selfVal - avg;
    const tag = Math.abs(delta) < 0.3 ? "≈ realistisch" : delta > 0 ? "⬆ du schätzt dich höher" : "⬇ andere sehen dich stärker";
    return [`  • ${dim.name.padEnd(20)}: du=${selfVal.toFixed(1)}  andere=Ø${avg.toFixed(2)}  delta=${delta > 0 ? "+" : ""}${delta.toFixed(2)}  (${tag})`];
  }).join("\n");

  const highCount = Math.max(2, Math.ceil(n * 0.40));
  const modCount  = Math.max(1, Math.ceil(n * 0.20));

  const relevantLicenses = flightLicenses.filter((l) => l !== "None");
  const licenseSection = relevantLicenses.length > 0
    ? `\n\nCANDIDATE FLIGHT LICENSES: ${relevantLicenses.join(", ")} — Tailor interviewTips and assessmentAdvice to reflect assessment questions typical for this license type.`
    : "";

  return `You are an expert aviation psychologist conducting a structured 360-degree feedback analysis for a pilot candidate preparing for a ${assessmentType} selection process.

## EVALUATION DIMENSIONS
Assess the candidate on these 10 aviation psychology dimensions:
1. Teamfähigkeit & Kooperation
2. Kommunikation
3. Führungsverhalten
4. Belastbarkeit & Stressresistenz
5. Selbstwahrnehmung & Reflexionsfähigkeit
6. Lernbereitschaft
7. Entscheidungsverhalten
8. Zuverlässigkeit & Verantwortungsbewusstsein
9. Soziale Kompetenz
10. Struktur & Organisation

## RATING DATA (for selfVsOthers)
${ratingsBlock || "  (no rating questions answered)"}

Evidence thresholds for ${n} respondents: HIGH ≥${highCount}, MODERATE ${modCount}–${highCount - 1}

## INPUT DATA

SELF-PERCEPTION:
${format(selfResponses)}${licenseSection}

EXTERNAL PERCEPTION (${n} respondents):
${externalResponses.map((r, i) => `Respondent ${i + 1}:\n${format(r)}`).join("\n\n")}

## LANGUAGE & TONE
Respond in German. Address the candidate DIRECTLY using "du".

## OUTPUT
Return ONLY valid JSON with exactly these keys (no markdown fences):
- personalitySummary: string (3–4 sentences, "du"-form)
- strengths: string array (3–5 items, format "Dimension: Beschreibung")
- weaknesses: string array (3–5 items, format "Dimension: Beschreibung")
- selfVsOthers: string (2–3 sentences, use rating threshold rules)
- assessmentAdvice: string (concrete, personalized, "du"-form)
- groupExerciseTips: string array (3–5 tips)
- interviewTips: string array (3–5 tips)
- decisionMakingTips: string array (3–5 tips)
- selfAwarenessTips: string array (3–5 tips)
- interviewSimulationQuestions: string array (exactly 3 personal interview questions in German, "du"-form, probe weak points)`;
}

// ─── Compute stats locally ────────────────────────────────────────────────────

export function computeComparisonAreas(
  selfR: Record<string, AnswerValue>,
  others: Record<string, AnswerValue>[]
): ComparisonArea[] {
  const dims = [
    {id:"q5",name:"Teamwork"},{id:"q6",name:"Stressresistenz"},{id:"q7",name:"Verantwortung"},
    {id:"q8",name:"Kommunikation"},{id:"q9",name:"Zuverlässigkeit"},{id:"q10_org",name:"Struktur/Organisation"},
  ];
  return dims.flatMap((q) => {
    const selfA = selfR[q.id];
    const selfVal = selfA?.type === "rating" ? selfA.value : 0;
    const otherVals = others.flatMap((r) => {
      const a = r[q.id];
      return (a?.type === "rating") ? [a.value] : [];
    });
    if (otherVals.length === 0) return [];
    const avg = otherVals.reduce((s,v) => s+v, 0) / otherVals.length;
    return [{ id: q.id, name: q.name, selfRating: selfVal, othersAverage: avg }];
  });
}

export function computeTraitStats(
  selfR: Record<string, AnswerValue>,
  others: Record<string, AnswerValue>[]
): TraitStat[] {
  const canonical = SURVEY_QUESTIONS.find((q) => q.id === "q1")?.options ?? [];
  const selfSelected = new Set<string>(
    selfR["q1"]?.type === "multipleChoice" ? selfR["q1"].value : []
  );
  return canonical.map((trait, i) => {
    const count = others.filter((r) => {
      const a = r["q1"];
      return a?.type === "multipleChoice" && a.value.includes(trait);
    }).length;
    return {
      id: `trait_${i}`, name: trait,
      selfSelected: selfSelected.has(trait),
      othersPercent: others.length ? count / others.length : 0,
    };
  });
}

export function computeForcedChoiceStats(
  selfR: Record<string, AnswerValue>,
  others: Record<string, AnswerValue>[]
): ForcedChoiceStat[] {
  const fcQ = [
    {id:"q2",text:"Entscheidet eher..."},
    {id:"q3",text:"In Gruppen tendiert diese Person..."},
    {id:"q4",text:"Wenn etwas schiefläuft..."},
  ];
  return fcQ.flatMap(({id,text}) => {
    const opts = SURVEY_QUESTIONS.find((q) => q.id === id)?.options ?? [];
    const selfChoice = selfR[id]?.type === "singleChoice" ? selfR[id].value : "";
    const counts: Record<string, number> = Object.fromEntries(opts.map((o) => [o, 0]));
    others.forEach((r) => {
      const a = r[id];
      if (a?.type === "singleChoice") counts[a.value] = (counts[a.value] ?? 0) + 1;
    });
    const total = others.length;
    const results = Object.fromEntries(Object.entries(counts).map(([k,v]) => [k, total ? v/total : 0]));
    return [{ id, question: text, selfChoice, results }];
  });
}

// ─── Parse AI response ────────────────────────────────────────────────────────

export function parseAnalysis(
  jsonStr: string,
  selfResponses: Record<string, AnswerValue>,
  externalResponses: Record<string, AnswerValue>[],
  respondentCount: number,
  existingResult?: AnalysisResult | null
): AnalysisResult | null {
  let cleaned = jsonStr.trim();
  if (cleaned.startsWith("```")) {
    cleaned = cleaned.split("\n").slice(1).join("\n");
    if (cleaned.endsWith("```")) cleaned = cleaned.slice(0, -3);
    cleaned = cleaned.trim();
  }
  let obj: Record<string, unknown>;
  try { obj = JSON.parse(cleaned); } catch { return null; }

  function strings(key: string): string[] { return (obj[key] as string[]) ?? []; }

  // Cache interview simulation questions
  const interviewQs = strings("interviewSimulationQuestions");
  if (interviewQs.length > 0) {
    localStorage.setItem("pm_interview_questions_v1", JSON.stringify(interviewQs));
  }

  return {
    personalitySummary:  (obj.personalitySummary as string) ?? "",
    perceivedStrengths:  strings("strengths"),
    possibleWeaknesses:  strings("weaknesses"),
    selfVsOthers:        (obj.selfVsOthers as string) ?? "",
    assessmentAdvice:    (obj.assessmentAdvice as string) ?? "",
    groupExerciseTips:   strings("groupExerciseTips"),
    interviewTips:       strings("interviewTips"),
    decisionMakingTips:  strings("decisionMakingTips"),
    selfAwarenessTips:   strings("selfAwarenessTips"),
    comparisonAreas:     computeComparisonAreas(selfResponses, externalResponses),
    traitStats:          computeTraitStats(selfResponses, externalResponses),
    forcedChoiceStats:   computeForcedChoiceStats(selfResponses, externalResponses),
    openTextResponses:   collectOpenText(externalResponses),
    motivationConfidenceAvg:   existingResult?.motivationConfidenceAvg,
    motivationConfidenceCount: existingResult?.motivationConfidenceCount ?? 0,
    motivationWishes:          existingResult?.motivationWishes ?? [],
    respondentCount,
    generatedAt: new Date().toISOString(),
  };
}

function collectOpenText(responses: Record<string, AnswerValue>[]): string[] {
  const openIds = ["q10","q11","q12","q13","q14","q15","q16","q17","q18"];
  return responses.flatMap((resp) =>
    openIds.flatMap((id) => {
      const a = resp[id];
      if (a?.type !== "text") return [];
      const text = a.value.trim();
      return isMeaningfulText(text) ? [text] : [];
    })
  );
}

function isMeaningfulText(t: string): boolean {
  const lower = t.toLowerCase();
  if (lower.length < 4) return false;
  const letterCount = lower.split("").filter((c) => /[a-züäöß\s]/.test(c)).length;
  if (letterCount / lower.length < 0.6) return false;
  const nonAnswers = ["keine ahnung","weiß nicht","weiss nicht","n/a","nichts","nein","ja","gut","okay","ok"];
  return !nonAnswers.some((na) => lower.startsWith(na) || lower === na);
}

// ─── Store result to Supabase ─────────────────────────────────────────────────

export async function storeResult(result: AnalysisResult, sessionId: string): Promise<void> {
  // Save to localStorage first
  localStorage.setItem("pm_analysis_result_v1", JSON.stringify(result));

  const areasJSON  = JSON.stringify(result.comparisonAreas);
  const traitsJSON = JSON.stringify(result.traitStats);
  const fcJSON     = JSON.stringify(result.forcedChoiceStats);

  await supabase.from("analysis_results").upsert({
    id: crypto.randomUUID(),
    session_id: sessionId,
    personality_summary: result.personalitySummary,
    strengths: result.perceivedStrengths,
    weaknesses: result.possibleWeaknesses,
    self_vs_others: result.selfVsOthers,
    assessment_advice: result.assessmentAdvice,
    group_exercise_tips: result.groupExerciseTips,
    interview_tips: result.interviewTips,
    decision_making_tips: result.decisionMakingTips,
    self_awareness_tips: result.selfAwarenessTips,
    comparison_areas: areasJSON,
    trait_stats: traitsJSON,
    forced_choice_stats: fcJSON,
    open_text_responses: result.openTextResponses,
    respondent_count_at_analysis: result.respondentCount,
    motivation_confidence_avg:   result.motivationConfidenceAvg ?? null,
    motivation_confidence_count: result.motivationConfidenceCount ?? null,
    motivation_wishes:           result.motivationWishes ?? [],
  }, { onConflict: "session_id" });

  // Persist interview questions separately (requires column — see migration below)
  try {
    const iqs = localStorage.getItem("pm_interview_questions_v1");
    if (iqs) {
      await supabase.from("analysis_results")
        .update({ interview_simulation_questions: JSON.parse(iqs) })
        .eq("session_id", sessionId);
    }
  } catch { /* column may not exist yet */ }
}

// ─── Main analysis entry point ────────────────────────────────────────────────

export async function runAnalysis(
  assessmentType: string,
  userId: string,
  flightLicenses: FlightLicense[],
  existingResult?: AnalysisResult | null
): Promise<AnalysisResult> {
  const sessionId = localStorage.getItem("pm_session_id");
  if (!sessionId) throw new Error("No session ID found");

  const [selfResponses, feedbackLinkStr] = [
    await loadSelfResponses(sessionId),
    localStorage.getItem("pm_feedback_link"),
  ];

  const feedbackLink = feedbackLinkStr ? JSON.parse(feedbackLinkStr) : null;
  if (!feedbackLink) throw new Error("No feedback link found");

  const externalResponses = await loadRespondentResponses(feedbackLink.id);
  if (externalResponses.length < 5) {
    throw new Error(`Not enough responses: ${externalResponses.length} (need 5)`);
  }

  const prompt = buildPrompt(assessmentType, selfResponses, externalResponses, flightLicenses);

  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.access_token) throw new Error("Not authenticated");

  const res = await fetch(ANALYZE_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${session.access_token}`,
      "apikey": SUPABASE_ANON,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ prompt }),
  });

  const json = await res.json();
  if (json.error) throw new Error(json.error);
  if (!json.result) throw new Error("No result from AI");

  // Compute stats first (immediate feedback)
  const statsOnly: AnalysisResult = {
    personalitySummary: "",
    perceivedStrengths: [],
    possibleWeaknesses: [],
    selfVsOthers: "",
    assessmentAdvice: "",
    groupExerciseTips: [],
    interviewTips: [],
    decisionMakingTips: [],
    selfAwarenessTips: [],
    comparisonAreas: computeComparisonAreas(selfResponses, externalResponses),
    traitStats: computeTraitStats(selfResponses, externalResponses),
    forcedChoiceStats: computeForcedChoiceStats(selfResponses, externalResponses),
    openTextResponses: collectOpenText(externalResponses),
    respondentCount: externalResponses.length,
    generatedAt: new Date().toISOString(),
    motivationConfidenceAvg: existingResult?.motivationConfidenceAvg,
    motivationConfidenceCount: existingResult?.motivationConfidenceCount ?? 0,
    motivationWishes: existingResult?.motivationWishes ?? [],
  };

  const parsed = parseAnalysis(json.result, selfResponses, externalResponses, externalResponses.length, existingResult);
  const result = parsed ?? statsOnly;

  await storeResult(result, sessionId);
  return result;
}
