import Foundation

struct Respondent: Identifiable, Codable {
    let id: String
    let feedbackLinkId: String
    var name: String
    var relationship: RelationshipType
    var confidenceRating: Int?   // 1–5, optional
    var wishText: String?        // optional free-text wish

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
        var labelDE: String {
            switch self {
            case .friend:           return "Freund/in"
            case .family:           return "Familie"
            case .colleague:        return "Kollege/in"
            case .flightInstructor: return "Fluglehrer/in"
            case .other:            return "Sonstiges"
            }
        }
        var labelEN: String {
            switch self {
            case .friend:           return "Friend"
            case .family:           return "Family"
            case .colleague:        return "Colleague"
            case .flightInstructor: return "Flight Instructor"
            case .other:            return "Other"
            }
        }
    }
}
