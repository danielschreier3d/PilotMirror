import Foundation

struct User: Identifiable, Codable {
    let id: String
    var name: String
    var email: String
    var assessmentType: AssessmentType?

    enum AssessmentType: String, Codable, CaseIterable {
        case europeanFlightAcademy = "European Flight Academy"
        case austrianAirlines     = "Austrian Airlines"
        case condor               = "Condor"
        case aerologic            = "AeroLogic"
        case general              = "General Pilot Assessment"

        var icon: String {
            switch self {
            case .europeanFlightAcademy: return "airplane.circle.fill"
            case .austrianAirlines:      return "airplane.departure"
            case .condor:                return "sun.horizon.fill"
            case .aerologic:             return "shippingbox.fill"
            case .general:               return "checkmark.seal.fill"
            }
        }

        var descriptionDE: String {
            switch self {
            case .europeanFlightAcademy: return "Vorbereitung auf das EFA Multi-Crew-Selection"
            case .austrianAirlines:      return "Vorbereitung auf das Austrian Airlines Assessment"
            case .condor:                return "Vorbereitung auf das Condor Piloten-Assessment"
            case .aerologic:             return "Vorbereitung auf das AeroLogic Assessment"
            case .general:               return "Allgemeines Piloten-Auswahlverfahren"
            }
        }

        var descriptionEN: String {
            switch self {
            case .europeanFlightAcademy: return "Prepare for the EFA multi-crew selection"
            case .austrianAirlines:      return "Prepare for the Austrian Airlines assessment"
            case .condor:                return "Prepare for the Condor pilot assessment"
            case .aerologic:             return "Prepare for the AeroLogic assessment"
            case .general:               return "General airline pilot selection process"
            }
        }
    }
}
