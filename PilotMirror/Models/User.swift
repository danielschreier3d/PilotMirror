import Foundation

struct User: Identifiable, Codable {
    let id: String
    var name: String
    var email: String
    var assessmentType: AssessmentType?
    var flightLicenses: [FlightLicense]?

    var firstName: String { name.components(separatedBy: " ").first ?? name }

    enum FlightLicense: String, Codable, CaseIterable {
        case ppl        = "PPL"
        case tmg        = "TMG"
        case lapl       = "LAPL"
        case ultralight = "UL"
        case paramotor  = "Paramotor"
        case other      = "Other"
        case none       = "None"

        var icon: String {
            switch self {
            case .ppl, .tmg, .lapl: return "airplane"
            case .ultralight:       return "wind"
            case .paramotor:        return "figure.hiking"
            case .other:            return "star"
            case .none:             return "minus.circle"
            }
        }
        var labelDE: String {
            switch self {
            case .ppl:        return "PPL (Privatpilotenlizenz)"
            case .tmg:        return "TMG (Motorsegler)"
            case .lapl:       return "LAPL (Leichte Luftfahrzeuge)"
            case .ultralight: return "UL (Ultraleichtflugzeug)"
            case .paramotor:  return "Paramotor"
            case .other:      return "Sonstige Lizenz"
            case .none:       return "Keine Fluglizenz"
            }
        }
        var labelEN: String {
            switch self {
            case .ppl:        return "PPL (Private Pilot Licence)"
            case .tmg:        return "TMG (Touring Motor Glider)"
            case .lapl:       return "LAPL (Light Aircraft)"
            case .ultralight: return "Ultralight Aircraft"
            case .paramotor:  return "Paramotor"
            case .other:      return "Other Licence"
            case .none:       return "No Flight Licence"
            }
        }
        var descriptionDE: String {
            switch self {
            case .ppl:        return "Privatpilotenlizenz für Motorflugzeuge"
            case .tmg:        return "Lizenz für motorisierte Segelflugzeuge"
            case .lapl:       return "Lizenz für leichte Luftfahrzeuge"
            case .ultralight: return "Lizenz für Ultraleichtflugzeuge"
            case .paramotor:  return "Motorisiertes Gleitschirmfliegen"
            case .other:      return "Andere Pilotenlizenz oder Berechtigung"
            case .none:       return "Noch keine Flugerfahrung als Pilot/in"
            }
        }
        var descriptionEN: String {
            switch self {
            case .ppl:        return "Private pilot licence for powered aircraft"
            case .tmg:        return "Licence for touring motor gliders"
            case .lapl:       return "Licence for light aircraft"
            case .ultralight: return "Ultralight aircraft licence"
            case .paramotor:  return "Motorised paragliding"
            case .other:      return "Other pilot licence or rating"
            case .none:       return "No flying experience as pilot yet"
            }
        }
    }

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
