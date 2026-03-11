import Foundation

struct Respondent: Identifiable, Codable {
    let id: String
    let feedbackLinkId: String
    var name: String
    var relationship: RelationshipType

    enum RelationshipType: String, Codable, CaseIterable {
        case friend          = "Friend"
        case family          = "Family"
        case colleague       = "Colleague"
        case flightInstructor = "Flight Instructor"
        case other           = "Other"

        var icon: String {
            switch self {
            case .friend:           return "person.2.fill"
            case .family:           return "house.fill"
            case .colleague:        return "briefcase.fill"
            case .flightInstructor: return "airplane"
            case .other:            return "person.fill"
            }
        }
    }
}
