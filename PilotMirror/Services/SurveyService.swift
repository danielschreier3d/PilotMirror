import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Backend DTOs
// ─────────────────────────────────────────────────────────────────────────────
private struct SelfResponseInsert: Encodable {
    let id: String; let sessionId: String; let questionId: String; let answerJson: AnswerValue
}

private struct SelfResponseRead: Decodable {
    let questionId: String; let answerJson: AnswerValue
}

private struct SessionRecord: Codable {
    let id: String; let userId: String; let status: String
}

private struct SessionInsert: Encodable {
    let id: String; let userId: String; let status: String
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SurveyService
// ─────────────────────────────────────────────────────────────────────────────
@MainActor
final class SurveyService: ObservableObject {
    static let shared = SurveyService()

    @Published var selfResponses: [String: AnswerValue] = [:]
    @Published var isSubmitting = false

    var questions: [Question] { Question.surveyQuestions }

    private let sb = SupabaseClient.shared

    private init() {
        if let data = UserDefaults.standard.data(forKey: "pm_self_responses"),
           let decoded = try? JSONDecoder().decode([String: AnswerValue].self, from: data) {
            selfResponses = decoded
        }
    }

    // MARK: – Submit self-assessment to backend

    func submitSelfAssessment(candidateId: String, responses: [String: AnswerValue]) async {
        isSubmitting = true; defer { isSubmitting = false }
        selfResponses = responses

        // Cache locally
        if let data = try? JSONEncoder().encode(responses) {
            UserDefaults.standard.set(data, forKey: "pm_self_responses")
        }

        guard let sessionId = await getOrCreateSession(userId: candidateId) else { return }

        for (questionId, answer) in responses {
            let record = SelfResponseInsert(
                id: UUID().uuidString, sessionId: sessionId,
                questionId: questionId, answerJson: answer)
            try? await sb.insert(into: "self_responses", value: record)
        }
    }

    // MARK: – Load responses from backend (used before analysis)

    func loadSelfResponses(userId: String) async {
        guard let sessionId = UserDefaults.standard.string(forKey: "pm_session_id") else { return }
        if let records: [SelfResponseRead] = try? await sb.select(
            from: "self_responses", filters: ["session_id": "eq.\(sessionId)"]) {
            selfResponses = Dictionary(uniqueKeysWithValues:
                records.map { ($0.questionId, $0.answerJson) })
            if let data = try? JSONEncoder().encode(selfResponses) {
                UserDefaults.standard.set(data, forKey: "pm_self_responses")
            }
        }
    }

    // MARK: – Session management (shared with FeedbackService)

    func getOrCreateSession(userId: String) async -> String? {
        if let cached = UserDefaults.standard.string(forKey: "pm_session_id") { return cached }
        if let existing: SessionRecord = try? await sb.selectFirst(
            from: "assessment_sessions",
            filters: ["user_id": "eq.\(userId)", "status": "eq.active"]) {
            UserDefaults.standard.set(existing.id, forKey: "pm_session_id")
            return existing.id
        }
        let newId = UUID().uuidString
        try? await sb.insert(into: "assessment_sessions",
                             value: SessionInsert(id: newId, userId: userId, status: "active"))
        UserDefaults.standard.set(newId, forKey: "pm_session_id")
        return newId
    }
}
