import Foundation

// Flexible JSON value decoder for survey answer_json
private struct AnyCodable: Decodable {
    let stringValue: String?
    let intValue: Int?
    let arrayValue: [String]?

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self)        { intValue = i; stringValue = nil; arrayValue = nil }
        else if let d = try? c.decode(Double.self) { intValue = Int(d); stringValue = nil; arrayValue = nil }
        else if let s = try? c.decode(String.self) { stringValue = s; intValue = nil; arrayValue = nil }
        else if let a = try? c.decode([String].self) { arrayValue = a; stringValue = nil; intValue = nil }
        else { stringValue = nil; intValue = nil; arrayValue = nil }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Backend DTOs
// ─────────────────────────────────────────────────────────────────────────────
private struct FeedbackLinkInsert: Encodable {
    let id: String; let sessionId: String; let token: String; let responseCount: Int
}

private struct FeedbackLinkRead: Decodable {
    let id: String; let sessionId: String; let token: String
    let responseCount: Int; let createdAt: Date?
}

private struct RespondentInsert: Encodable {
    let id: String; let feedbackLinkId: String; let name: String; let relationship: String
}

private struct RespondentRead: Decodable {
    let id: String
    let feedbackLinkId: String
}

private struct SurveyResponseInsert: Encodable {
    let id: String; let respondentId: String; let questionId: String; let answerJson: AnswerValue
}

// RPC return type for get_link_by_token
private struct LinkTokenResult: Decodable {
    let linkId: String; let sessionId: String
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - FeedbackService
// ─────────────────────────────────────────────────────────────────────────────
@MainActor
final class FeedbackService: ObservableObject {
    static let shared = FeedbackService()

    @Published var feedbackLink: FeedbackLink?
    @Published var respondents:  [Respondent] = []
    @Published var isLoading  = false
    @Published var error:       String?

    private let sb = SupabaseClient.shared

    private init() {}

    // MARK: – Create feedback link

    func createFeedbackLink(candidateId: String) async throws -> FeedbackLink {
        isLoading = true; defer { isLoading = false }

        let sessionId = await SurveyService.shared.getOrCreateSession(userId: candidateId)
            ?? UUID().uuidString
        let token   = generateToken()
        let linkId  = UUID().uuidString

        let record = FeedbackLinkInsert(
            id: linkId, sessionId: sessionId, token: token, responseCount: 0)
        try await sb.insert(into: "feedback_links", value: record)

        let link = FeedbackLink(id: linkId, sessionId: sessionId,
                                token: token, createdAt: Date(), responseCount: 0)
        feedbackLink = link
        persist(link)
        return link
    }

    // MARK: – Load user data from Supabase (called on app start after login)

    func loadForUser(userId: String) async {
        // 1. Find existing session (don't create one — that happens on self-assessment submit)
        struct SessionRead: Decodable { let id: String }
        guard let session: SessionRead = try? await sb.selectFirst(
            from: "assessment_sessions",
            filters: ["candidate_id": "eq.\(userId)"]
        ) else { return }  // No session yet — user hasn't submitted self-assessment

        // Cache session ID for other services
        UserDefaults.standard.set(session.id, forKey: "pm_session_id")

        // 2. Load self-responses
        await SurveyService.shared.loadSelfResponses(userId: userId)

        // 3. Load feedback link
        if let record: FeedbackLinkRead = try? await sb.selectFirst(
            from: "feedback_links",
            filters: ["session_id": "eq.\(session.id)"]
        ) {
            let link = FeedbackLink(
                id: record.id, sessionId: record.sessionId, token: record.token,
                createdAt: record.createdAt ?? Date(), responseCount: record.responseCount)
            feedbackLink = link
            persist(link)
        }
    }

    // MARK: – Load saved link from cache

    func loadSavedLink() {
        if let data = UserDefaults.standard.data(forKey: "pm_feedback_link"),
           let link = try? JSONDecoder().decode(FeedbackLink.self, from: data) {
            feedbackLink = link
        }
    }

    // MARK: – Refresh response count from Supabase

    func refreshStatus() async {
        guard let link = feedbackLink else { return }
        isLoading = true; defer { isLoading = false }
        do {
            if let record: FeedbackLinkRead = try await sb.selectFirst(
                from: "feedback_links", filters: ["id": "eq.\(link.id)"]
            ) {
                let updated = FeedbackLink(
                    id: record.id, sessionId: record.sessionId, token: record.token,
                    createdAt: record.createdAt ?? Date(), responseCount: record.responseCount)
                feedbackLink = updated
                persist(updated)
            }
        } catch { self.error = error.localizedDescription }
    }

    // MARK: – Submit full respondent survey (called from FeedbackSurveyView)

    func submitRespondentSurvey(
        token: String,
        name: String,
        relationship: Respondent.RelationshipType,
        responses: [String: AnswerValue]
    ) async throws {
        isLoading = true; defer { isLoading = false }

        // 1. Look up link by token (anon — no auth required)
        let results: [LinkTokenResult] = try await sb.rpc(
            function: "get_link_by_token",
            params: ["p_token": token],
            anonOnly: true)
        guard let linkInfo = results.first else {
            throw SupabaseError.noData
        }

        // 2. Create respondent record
        let respondentId = UUID().uuidString
        try await sb.insert(
            into: "respondents",
            value: RespondentInsert(
                id: respondentId, feedbackLinkId: linkInfo.linkId,
                name: name, relationship: relationship.rawValue),
            anonOnly: true)

        // 3. Submit all survey responses
        for (questionId, answer) in responses {
            try await sb.insert(
                into: "survey_responses",
                value: SurveyResponseInsert(
                    id: UUID().uuidString, respondentId: respondentId,
                    questionId: questionId, answerJson: answer),
                anonOnly: true)
        }

        // 4. Increment response count
        try await sb.rpcVoid(
            function: "increment_response_count",
            params: ["p_link_id": linkInfo.linkId],
            anonOnly: true)
    }

    // MARK: – Load respondent survey responses for AI analysis

    func loadRespondentResponses() async throws -> [[String: AnswerValue]] {
        guard let link = feedbackLink else { return [] }

        struct Row: Decodable {
            let respondentId: String
            let questionId: String
            let answerType: String
            let answerValue: String
        }

        let rows: [Row] = try await sb.rpc(
            function: "get_all_respondent_data",
            params: ["p_link_id": link.id])

        // Group rows by respondentId
        var byRespondent: [String: [String: AnswerValue]] = [:]
        for row in rows {
            let ans: AnswerValue?
            switch row.answerType {
            case "single":   ans = .singleChoice(row.answerValue)
            case "multiple":
                if let data = row.answerValue.data(using: .utf8),
                   let arr = try? JSONDecoder().decode([String].self, from: data) {
                    ans = .multipleChoice(arr)
                } else { ans = .multipleChoice([row.answerValue]) }
            case "rating":   ans = Int(row.answerValue).map { .rating($0) }
            case "text":     ans = .text(row.answerValue)
            default:         ans = nil
            }
            if let ans {
                byRespondent[row.respondentId, default: [:]][row.questionId] = ans
            }
        }

        return byRespondent.values.filter { !$0.isEmpty }.map { $0 }
    }

    // MARK: – Private helpers

    private func persist(_ link: FeedbackLink) {
        if let data = try? JSONEncoder().encode(link) {
            UserDefaults.standard.set(data, forKey: "pm_feedback_link")
        }
    }

    private func generateToken() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<10).map { _ in chars.randomElement()! })
    }
}
