import Foundation

struct FeedbackLink: Identifiable, Codable {
    let id:            String
    let sessionId:     String   // references assessment_sessions.id
    let token:         String
    let createdAt:     Date
    var responseCount: Int

    /// Web survey URL — update WebConfig.surveyBase after Vercel deploy
    var shareURL: URL { URL(string: shareURLString)! }

    var shareURLString: String {
        "\(WebConfig.surveyBase)/feedback/\(token)"
    }
}
