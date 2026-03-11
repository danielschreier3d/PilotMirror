import Foundation

struct User: Identifiable, Codable {
    let id: String
    var name: String
    var email: String
    var assessmentType: AssessmentType?

    enum AssessmentType: String, Codable, CaseIterable {
        case europeanFlightAcademy = "European Flight Academy"
        case dlr = "DLR Assessment"
        case general = "General Pilot Assessment"

        var icon: String {
            switch self {
            case .europeanFlightAcademy: return "airplane.circle.fill"
            case .dlr: return "brain.head.profile"
            case .general: return "checkmark.seal.fill"
            }
        }

        var description: String {
            switch self {
            case .europeanFlightAcademy: return "Prepare for the EFA multi-crew selection"
            case .dlr: return "German Aerospace Center assessment prep"
            case .general: return "General airline pilot selection process"
            }
        }
    }
}
