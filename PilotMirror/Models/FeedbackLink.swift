import Foundation

struct FeedbackLink: Identifiable, Codable {
    let id: String
    let candidateId: String
    let token: String
    let createdAt: Date
    var responseCount: Int

    var shareURL: URL {
        URL(string: "https://pilotmirror.app/feedback/\(token)")!
    }

    var shareURLString: String {
        "https://pilotmirror.app/feedback/\(token)"
    }
}
