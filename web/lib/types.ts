// ─── User ────────────────────────────────────────────────────────────────────

export type FlightLicense =
  | "PPL" | "TMG" | "LAPL" | "UL" | "Paramotor" | "Other" | "None";

export type AssessmentType =
  | "European Flight Academy"
  | "Austrian Airlines"
  | "Condor"
  | "AeroLogic"
  | "General Pilot Assessment";

export interface User {
  id: string;
  name: string;
  email: string;
  assessmentType?: AssessmentType;
  flightLicenses?: FlightLicense[];
}

export function firstName(fullName?: string): string {
  if (!fullName) return "";
  return fullName.split(" ")[0] ?? fullName;
}

// ─── Survey / Answers ────────────────────────────────────────────────────────

export type QuestionType = "traitSelection" | "forcedChoice" | "ratingScale" | "openText";
export type SurveyMode   = "selfAssessment" | "respondent";

export interface Question {
  id: string;
  type: QuestionType;
  text: string;           // German third-person
  textEN?: string;
  textSelf?: string;      // German first-person
  textSelfEN?: string;
  options?: string[];     // German canonical
  optionsEN?: string[];
  scaleMin?: number;
  scaleMax?: number;
  placeholder?: string;
  placeholderEN?: string;
  section: number;
  sectionTitle: string;
  sectionTitleEN: string;
}

export type AnswerValue =
  | { type: "multipleChoice"; value: string[] }
  | { type: "singleChoice";   value: string  }
  | { type: "rating";         value: number  }
  | { type: "text";           value: string  };

export type Answers = Record<string, AnswerValue>;

export function displayText(q: Question, mode: SurveyMode, isGerman: boolean, candidateName?: string): string {
  if (mode === "selfAssessment") {
    if (isGerman) return q.textSelf ?? q.text;
    return q.textSelfEN ?? q.textEN ?? q.text;
  }
  // respondent
  const base = isGerman ? q.text : (q.textEN ?? q.text);
  if (!candidateName) return base;
  return base
    .replace(/Diese Person/g, candidateName)
    .replace(/diese Person/g, candidateName)
    .replace(/dieser Person/g, candidateName)
    .replace(/This person's/g, `${candidateName}'s`)
    .replace(/this person's/g, `${candidateName}'s`)
    .replace(/This person/g, candidateName)
    .replace(/this person/g, candidateName);
}

export function displayOptions(q: Question, isGerman: boolean): string[] | undefined {
  return isGerman ? q.options : (q.optionsEN ?? q.options);
}

export function displayPlaceholder(q: Question, isGerman: boolean): string | undefined {
  return isGerman ? q.placeholder : (q.placeholderEN ?? q.placeholder);
}

// ─── Analysis ────────────────────────────────────────────────────────────────

export interface ComparisonArea {
  id: string;
  name: string;
  selfRating: number;
  othersAverage: number;
}

export interface TraitStat {
  id: string;
  name: string;
  selfSelected: boolean;
  othersPercent: number;
}

export interface ForcedChoiceStat {
  id: string;
  question: string;
  selfChoice: string;
  results: Record<string, number>;
}

export interface AnalysisResult {
  personalitySummary: string;
  perceivedStrengths: string[];
  possibleWeaknesses: string[];
  selfVsOthers: string;
  assessmentAdvice: string;
  groupExerciseTips: string[];
  interviewTips: string[];
  decisionMakingTips: string[];
  selfAwarenessTips: string[];
  comparisonAreas: ComparisonArea[];
  traitStats: TraitStat[];
  forcedChoiceStats: ForcedChoiceStat[];
  openTextResponses: string[];
  motivationConfidenceAvg?: number;
  motivationConfidenceCount?: number;
  motivationWishes?: string[];
  respondentCount: number;
  generatedAt: string;
}

export interface FeedbackLink {
  id: string;
  sessionId: string;
  token: string;
  responseCount: number;
  createdAt: string;
}

export function getFeedbackURL(token: string): string {
  const origin = typeof window !== "undefined"
    ? window.location.origin
    : "https://danielschreier3d.github.io";
  return `${origin}/PilotMirror/feedback?token=${token}`;
}

// ─── Respondent ──────────────────────────────────────────────────────────────

export type RelationshipType =
  | "colleague" | "friend" | "family" | "instructor" | "supervisor" | "other";

export const RELATIONSHIP_LABELS: Record<RelationshipType, { de: string; en: string }> = {
  colleague:   { de: "Kollege/Kollegin",    en: "Colleague"   },
  friend:      { de: "Freund/in",           en: "Friend"      },
  family:      { de: "Familie",             en: "Family"      },
  instructor:  { de: "Lehrer/in / Ausbilder", en: "Instructor" },
  supervisor:  { de: "Vorgesetzte/r",       en: "Supervisor"  },
  other:       { de: "Sonstige",            en: "Other"       },
};
