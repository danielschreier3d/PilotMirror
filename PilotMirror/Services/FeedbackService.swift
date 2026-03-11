import Foundation

@MainActor
final class FeedbackService: ObservableObject {
    static let shared = FeedbackService()

    @Published var feedbackLink: FeedbackLink?
    @Published var respondents: [Respondent] = []
    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    func createFeedbackLink(candidateId: String) async throws -> FeedbackLink {
        isLoading = true
        defer { isLoading = false }

        let token = generateToken()
        let link = FeedbackLink(
            id: UUID().uuidString,
            candidateId: candidateId,
            token: token,
            createdAt: Date(),
            responseCount: 0
        )

        // TODO: supabase.from("feedback_links").insert([
        //   "id": link.id, "candidate_id": candidateId, "token": token
        // ])

        feedbackLink = link
        // Persist locally
        if let data = try? JSONEncoder().encode(link) {
            UserDefaults.standard.set(data, forKey: "pm_feedback_link")
        }
        return link
    }

    func loadSavedLink() {
        if let data = UserDefaults.standard.data(forKey: "pm_feedback_link"),
           let link = try? JSONDecoder().decode(FeedbackLink.self, from: data) {
            feedbackLink = link
        }
    }

    func refreshStatus() async {
        guard let link = feedbackLink else { return }
        isLoading = true
        defer { isLoading = false }
        // TODO: let count = try await supabase.from("respondents")
        //   .select("id", count: .exact)
        //   .eq("feedback_link_id", link.id)
        //   .execute().count
        // Simulate increment for demo
        let mockCount = min((feedbackLink?.responseCount ?? 0) + 1, 12)
        feedbackLink = FeedbackLink(
            id: link.id, candidateId: link.candidateId, token: link.token,
            createdAt: link.createdAt, responseCount: mockCount
        )
    }

    func submitRespondent(name: String, relationship: Respondent.RelationshipType, linkToken: String) async throws -> Respondent {
        let respondent = Respondent(
            id: UUID().uuidString,
            feedbackLinkId: linkToken,
            name: name,
            relationship: relationship
        )
        // TODO: supabase.from("respondents").insert([...])
        respondents.append(respondent)
        return respondent
    }

    func submitResponses(_ responses: [String: AnswerValue], respondentId: String) async throws {
        // TODO: for each response insert into supabase.from("responses")
        isLoading = true
        defer { isLoading = false }
        try await Task.sleep(nanoseconds: 800_000_000) // Simulate network
    }

    private func generateToken() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<10).map { _ in chars.randomElement()! })
    }
}
