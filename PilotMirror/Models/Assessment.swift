import Foundation

struct Assessment: Identifiable, Codable {
    let id: String
    let candidateId: String
    let type: User.AssessmentType
    var feedbackLinkId: String?
    let createdAt: Date
    var responseCount: Int
    var selfCompleted: Bool
    var analysisResult: AnalysisResult?
}

// MARK: - Structured comparison data

struct ComparisonArea: Codable, Identifiable {
    let id: String
    let name: String
    let selfRating: Double      // 1–5 scale
    let othersAverage: Double   // 1–5 scale

    var delta: Double { selfRating - othersAverage }

    func gapLabel(isGerman: Bool) -> String {
        let d = delta
        if isGerman {
            if abs(d) < 0.3  { return "Realistische Einschätzung" }
            if d >= 0.3  && d < 0.7  { return "Du schätzt dich leicht höher ein" }
            if d >= 0.7              { return "Du überschätzt dich deutlich" }
            if d <= -0.3 && d > -0.7 { return "Andere sehen dich leicht stärker" }
            return "Andere sehen dich deutlich stärker"
        } else {
            if abs(d) < 0.3  { return "Realistic self-assessment" }
            if d >= 0.3  && d < 0.7  { return "Slight overestimation" }
            if d >= 0.7              { return "Significant overestimation" }
            if d <= -0.3 && d > -0.7 { return "Others see you slightly stronger" }
            return "Others see you as clearly stronger"
        }
    }

    var gapColor: String {
        if abs(delta) < 0.3 { return "4A9EF8" }
        if abs(delta) < 0.7 { return "FF9F0A" }
        if delta > 0        { return "FF6B6B" }
        return "34C759"
    }
}

struct TraitStat: Codable, Identifiable {
    let id: String
    let name: String
    let selfSelected: Bool
    let othersPercent: Double   // 0.0–1.0

    var surprise: Bool { abs((selfSelected ? 1.0 : 0.0) - othersPercent) > 0.4 }
}

struct ForcedChoiceStat: Codable, Identifiable {
    let id: String
    let question: String
    let selfChoice: String
    let results: [String: Double]   // option -> fraction (0–1)
}

// MARK: - Full analysis result

struct AnalysisResult: Codable {
    let personalitySummary: String
    let perceivedStrengths: [String]
    let possibleWeaknesses: [String]
    let selfVsOthers: String
    let assessmentAdvice: String
    let generatedAt: Date

    // Structured comparison data (computed from raw responses)
    let comparisonAreas:   [ComparisonArea]
    let traitStats:        [TraitStat]
    let forcedChoiceStats: [ForcedChoiceStat]
    let openTextResponses: [String]

    // Personalized AI-generated tips per assessment category
    let groupExerciseTips:  [String]
    let interviewTips:      [String]
    let decisionMakingTips: [String]
    let selfAwarenessTips:  [String]

    // Motivation data (NOT AI-analysed — from respondents' confidence + wishes)
    var motivationConfidenceAvg:   Double?   // average of 1–5 confidence ratings
    var motivationConfidenceCount: Int       // number of people who rated
    var motivationWishes:          [String]  // all non-empty wish texts

    // Snapshot of how many respondents were included when the AI ran
    var respondentCount: Int
}
