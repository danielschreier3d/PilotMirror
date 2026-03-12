import Foundation

struct FeedbackLink: Identifiable, Codable {
    let id:            String
    let sessionId:     String   // references assessment_sessions.id
    let token:         String
    let createdAt:     Date
    var responseCount: Int

    var shareURL: URL {
        // For production: replace with pilotmirror.app domain
        URL(string: "pilotmirror://feedback/\(token)")!
    }

    var shareURLString: String {
        // Show universal link format to users; app handles both schemes
        "https://pilotmirror.app/feedback/\(token)"
    }
}
