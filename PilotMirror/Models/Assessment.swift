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

    var gapLabel: String {
        let d = delta
        if abs(d) < 0.2 { return "Übereinstimmung" }
        if d > 0 { return "Du schätzt dich höher ein" }
        return "Andere sehen dich stärker"
    }

    var gapColor: String {
        if abs(delta) < 0.2 { return "34C759" }
        if delta > 0.5 { return "FF6B6B" }
        if delta < -0.5 { return "4A9EF8" }
        return "FF9F0A"
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
}
