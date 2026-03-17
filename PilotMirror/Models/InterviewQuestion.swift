import Foundation

// MARK: - InterviewCategory

enum InterviewCategory: String, CaseIterable {
    case math        = "Kopfrechnen"
    case physics     = "Physik & Technik"
    case navigation  = "Navigation & Wetter"
    case aviation    = "Luftfahrtkunde"
    case english     = "Aviation English"
    case spatial     = "Räumliches Denken"
    case personality = "Motivation & Persönlichkeit"
    case judgment    = "Situatives Urteil"
    case school      = "Flugschule & Ausbildung"

    var showsAnswer: Bool { self == .math || self == .spatial || self == .english }

    /// Whether the interviewer can request a live AI model answer for this category.
    var supportsAIHint: Bool {
        switch self {
        case .math, .physics, .navigation, .aviation, .english, .spatial, .judgment: return true
        case .personality, .school: return false
        }
    }

    var icon: String {
        switch self {
        case .math:        return "function"
        case .physics:     return "atom"
        case .navigation:  return "map.fill"
        case .aviation:    return "airplane"
        case .english:     return "globe"
        case .spatial:     return "cube.fill"
        case .personality: return "person.fill"
        case .judgment:    return "exclamationmark.triangle.fill"
        case .school:      return "graduationcap.fill"
        }
    }

    var labelEN: String {
        switch self {
        case .math:        return "Mental Math"
        case .physics:     return "Physics & Tech"
        case .navigation:  return "Navigation & Weather"
        case .aviation:    return "Aviation Knowledge"
        case .english:     return "Aviation English"
        case .spatial:     return "Spatial Reasoning"
        case .personality: return "Motivation & Personality"
        case .judgment:    return "Situational Judgment"
        case .school:      return "Flight School & Training"
        }
    }
}

// MARK: - SessionSize

enum SessionSize: CaseIterable {
    case small
    case medium
    case large

    var questionsPerCategory: Int {
        switch self { case .small: return 1; case .medium: return 2; case .large: return 3 }
    }

    var aiQuestionCount: Int {
        switch self { case .small: return 2; case .medium: return 3; case .large: return 4 }
    }

    func totalCount(hasAIQuestions: Bool) -> String {
        let base = InterviewCategory.allCases.count * questionsPerCategory
        let ai   = hasAIQuestions ? aiQuestionCount : 0
        return "~\(base + ai)"
    }

    var labelDE: String {
        switch self { case .small: return "Klein"; case .medium: return "Mittel"; case .large: return "Groß" }
    }
    var labelEN: String {
        switch self { case .small: return "Small"; case .medium: return "Medium"; case .large: return "Large" }
    }
    var descriptionDE: String {
        switch self {
        case .small:  return "1 Frage pro Kategorie"
        case .medium: return "2 Fragen pro Kategorie"
        case .large:  return "3 Fragen pro Kategorie"
        }
    }
    var descriptionEN: String {
        switch self {
        case .small:  return "1 question per category"
        case .medium: return "2 questions per category"
        case .large:  return "3 questions per category"
        }
    }
}

// MARK: - InterviewQuestion

struct InterviewQuestion: Identifiable {
    let id: String
    let category: InterviewCategory
    let de: String
    let en: String
    let answerDE: String?
    let answerEN: String?
    var followUpsDE: [String]? = nil
    var followUpsEN: [String]? = nil
    var requiresFlightExperience: Bool = false
    /// Licenses for which this question is NOT appropriate (e.g. night-flying questions for UL).
    var excludedLicenses: Set<User.FlightLicense> = []
    var isAIGenerated: Bool = false
}

// MARK: - Session Builder

extension InterviewQuestion {

    /// poolIndex 0/1/2 — each run draws from a different third of the question bank.
    static func randomSession(
        size: SessionSize,
        poolIndex: Int = 0,
        flightLicenses: [User.FlightLicense] = [],
        assessmentType: User.AssessmentType? = nil,
        aiQuestions: [InterviewQuestion] = []
    ) -> [InterviewQuestion] {
        let pool          = poolIndex % 3
        let licenseSet    = Set(flightLicenses)
        let hasExperience = flightLicenses.contains { $0 != .none }
        let schoolPool    = assessmentType.map { schoolQuestions(for: $0) } ?? []
        let fullPool      = all + schoolPool

        let staticQuestions: [InterviewQuestion] = InterviewCategory.allCases.flatMap { cat in
            let available = fullPool
                .filter { $0.category == cat }
                .filter { !$0.requiresFlightExperience || hasExperience }
                .filter { $0.excludedLicenses.isDisjoint(with: licenseSet) }
                .sorted { $0.id < $1.id }   // stable sort for deterministic splitting

            // Split into 3 balanced chunks; remainder distributed to first chunks
            let n = available.count
            let base = n / 3; let rem = n % 3
            var chunks: [[InterviewQuestion]] = []; var offset = 0
            for i in 0..<3 {
                let sz = base + (i < rem ? 1 : 0)
                chunks.append(Array(available[offset..<(offset + sz)]))
                offset += sz
            }
            return Array(chunks[pool].shuffled().prefix(size.questionsPerCategory))
        }

        let aiToInclude = Array(aiQuestions.shuffled().prefix(size.aiQuestionCount))
        return interleaved(staticQuestions, ai: aiToInclude)
    }

    private static func interleaved(
        _ base: [InterviewQuestion],
        ai: [InterviewQuestion]
    ) -> [InterviewQuestion] {
        guard !ai.isEmpty else { return base }
        var result = base
        let step = max(1, result.count / (ai.count + 1))
        for (i, q) in ai.enumerated() {
            let idx = min(step * (i + 1) + i, result.count)
            result.insert(q, at: idx)
        }
        return result
    }

    // MARK: - Dynamic School Questions

    static func schoolQuestions(for type: User.AssessmentType) -> [InterviewQuestion] {
        let name = type.rawValue
        return [
            .init(id: "sch01", category: .school,
                  de: "Warum möchtest du bei der \(name) ausgebildet werden?",
                  en: "Why do you want to train at \(name)?",
                  answerDE: nil, answerEN: nil,
                  followUpsDE: [
                    "Was weißt du konkret über die Ausbildung bei \(name)?",
                    "Hast du andere Flugschulen in Betracht gezogen? Warum \(name)?",
                    "Was erwartest du von uns als Ausbildungsorganisation?"
                  ],
                  followUpsEN: [
                    "What do you specifically know about training at \(name)?",
                    "Did you consider other schools? Why \(name)?",
                    "What do you expect from us as a training organisation?"
                  ]),
            .init(id: "sch02", category: .school,
                  de: "Was weißt du über den Ablauf der Ausbildung bei \(name)?",
                  en: "What do you know about the training process at \(name)?",
                  answerDE: nil, answerEN: nil,
                  followUpsDE: [
                    "Wie lange dauert die Ausbildung zum ATPL?",
                    "Was passiert, wenn du eine Phase nicht besteht?"
                  ],
                  followUpsEN: [
                    "How long does the ATPL training take?",
                    "What happens if you fail a phase?"
                  ]),
            .init(id: "sch03", category: .school,
                  de: "Wie hast du dich auf das Auswahlverfahren bei \(name) vorbereitet?",
                  en: "How did you prepare for the \(name) selection process?",
                  answerDE: nil, answerEN: nil,
                  followUpsDE: [
                    "Was war die größte Herausforderung in deiner Vorbereitung?",
                    "Hast du ein Bewerbungscoaching in Anspruch genommen?"
                  ],
                  followUpsEN: [
                    "What was the biggest challenge in your preparation?",
                    "Did you use any coaching services?"
                  ]),
            .init(id: "sch04", category: .school,
                  de: "Was erwartest du von deinen Ausbildern bei \(name)?",
                  en: "What do you expect from your instructors at \(name)?",
                  answerDE: nil, answerEN: nil),
            .init(id: "sch05", category: .school,
                  de: "Weißt du, welche Flugzeugmuster bei \(name) geflogen werden?",
                  en: "Do you know which aircraft types are used at \(name)?",
                  answerDE: nil, answerEN: nil),
            .init(id: "sch06", category: .school,
                  de: "Was würdest du tun, wenn du das Auswahlverfahren bei \(name) nicht besteht?",
                  en: "What would you do if you don't pass the \(name) selection?",
                  answerDE: nil, answerEN: nil,
                  followUpsDE: [
                    "Hast du einen Plan B?",
                    "Würdest du es erneut versuchen?"
                  ],
                  followUpsEN: [
                    "Do you have a plan B?",
                    "Would you try again?"
                  ]),
            .init(id: "sch07", category: .school,
                  de: "Wie finanzierst du die Ausbildung?",
                  en: "How are you planning to finance the training?",
                  answerDE: nil, answerEN: nil,
                  followUpsDE: [
                    "Hast du dich über Finanzierungsmöglichkeiten informiert?",
                    "Was passiert, wenn die Finanzierung nicht klappt?"
                  ],
                  followUpsEN: [
                    "Have you researched financing options?",
                    "What if the financing falls through?"
                  ]),
            .init(id: "sch08", category: .school,
                  de: "Haben Familie oder Partner die Entscheidung zur Pilotenausbildung unterstützt?",
                  en: "Have your family or partner supported your decision to pursue pilot training?",
                  answerDE: nil, answerEN: nil,
                  followUpsDE: [
                    "Wie geht dein Umfeld mit den langen Abwesenheiten um?",
                    "Was sagst du jemandem, der dir davon abrät?"
                  ],
                  followUpsEN: [
                    "How does your circle handle long absences?",
                    "What do you say to someone who advises against it?"
                  ]),
            .init(id: "sch09", category: .school,
                  de: "Was weißt du über die Karrieremöglichkeiten nach der Ausbildung bei \(name)?",
                  en: "What do you know about career opportunities after training at \(name)?",
                  answerDE: nil, answerEN: nil),
            .init(id: "sch10", category: .school,
                  de: "Welche Eigenschaften glaubst du, sucht \(name) in einem Kandidaten?",
                  en: "What qualities do you think \(name) looks for in a candidate?",
                  answerDE: nil, answerEN: nil,
                  followUpsDE: [
                    "Welche dieser Eigenschaften siehst du bei dir am stärksten?",
                    "Wo siehst du noch Entwicklungspotenzial?"
                  ],
                  followUpsEN: [
                    "Which of these do you see most strongly in yourself?",
                    "Where do you see room for development?"
                  ]),
            .init(id: "sch11", category: .school,
                  de: "Wie gehst du mit den Anforderungen um, gleichzeitig Theorie und Praxis zu meistern?",
                  en: "How will you handle the demands of mastering both theory and practical flying?",
                  answerDE: nil, answerEN: nil),
            .init(id: "sch12", category: .school,
                  de: "Wo siehst du dich 5 Jahre nach Abschluss der Ausbildung bei \(name)?",
                  en: "Where do you see yourself 5 years after completing training at \(name)?",
                  answerDE: nil, answerEN: nil,
                  followUpsDE: [
                    "Ist das realistisch? Was muss dafür alles klappen?",
                    "Was wenn der Arbeitsmarkt dann schwierig ist?"
                  ],
                  followUpsEN: [
                    "Is that realistic? What needs to go right?",
                    "What if the job market is tough then?"
                  ]),
        ]
    }

    // MARK: - Static Pool

    static let all: [InterviewQuestion] = math + physics + navigation + aviation + english + spatial + personality + judgment

    // ── Kopfrechnen ──────────────────────────────────────────────────────────
    static let math: [InterviewQuestion] = [
        .init(id: "m01", category: .math, de: "37 × 8 = ?", en: "37 × 8 = ?",
              answerDE: "296", answerEN: "296"),
        .init(id: "m02", category: .math, de: "144 ÷ 12 = ?", en: "144 ÷ 12 = ?",
              answerDE: "12", answerEN: "12"),
        .init(id: "m03", category: .math, de: "15 % von 240 = ?", en: "15 % of 240 = ?",
              answerDE: "36", answerEN: "36"),
        .init(id: "m04", category: .math, de: "125 × 4 = ?", en: "125 × 4 = ?",
              answerDE: "500", answerEN: "500"),
        .init(id: "m05", category: .math, de: "270 ÷ 9 = ?", en: "270 ÷ 9 = ?",
              answerDE: "30", answerEN: "30"),
        .init(id: "m06", category: .math, de: "23 + 47 + 86 = ?", en: "23 + 47 + 86 = ?",
              answerDE: "156", answerEN: "156"),
        .init(id: "m07", category: .math, de: "Quadratwurzel aus 196 = ?", en: "Square root of 196 = ?",
              answerDE: "14", answerEN: "14"),
        .init(id: "m08", category: .math, de: "3/4 von 480 = ?", en: "3/4 of 480 = ?",
              answerDE: "360", answerEN: "360"),
        .init(id: "m09", category: .math, de: "17 × 17 = ?", en: "17 × 17 = ?",
              answerDE: "289", answerEN: "289"),
        .init(id: "m10", category: .math,
              de: "450 km in 1,5 h → Durchschnittsgeschwindigkeit = ?",
              en: "450 km in 1.5 h → average speed = ?",
              answerDE: "300 km/h", answerEN: "300 km/h"),
        .init(id: "m11", category: .math, de: "360 ÷ 8 × 3 = ?", en: "360 ÷ 8 × 3 = ?",
              answerDE: "135", answerEN: "135"),
        .init(id: "m12", category: .math, de: "25 % von 360 = ?", en: "25 % of 360 = ?",
              answerDE: "90", answerEN: "90"),
        .init(id: "m13", category: .math,
              de: "Flugzeit: 780 km bei 260 km/h = ? Stunden",
              en: "Flight time: 780 km at 260 km/h = ? hours",
              answerDE: "3 Stunden", answerEN: "3 hours"),
    ]

    // ── Physik & Technik ─────────────────────────────────────────────────────
    static let physics: [InterviewQuestion] = [
        .init(id: "p01", category: .physics,
              de: "Was ist Auftrieb und wovon hängt er ab?",
              en: "What is lift and what does it depend on?",
              answerDE: nil, answerEN: nil),
        .init(id: "p02", category: .physics,
              de: "Erkläre das Bernoulli-Prinzip im Kontext des Fliegens.",
              en: "Explain the Bernoulli principle in the context of flight.",
              answerDE: nil, answerEN: nil),
        .init(id: "p03", category: .physics,
              de: "Was ist der Unterschied zwischen statischem und dynamischem Druck?",
              en: "What is the difference between static and dynamic pressure?",
              answerDE: nil, answerEN: nil),
        .init(id: "p04", category: .physics,
              de: "Warum nimmt die Luftdichte mit der Höhe ab?",
              en: "Why does air density decrease with altitude?",
              answerDE: nil, answerEN: nil),
        .init(id: "p05", category: .physics,
              de: "Was versteht man unter dem Überziehwinkel (Critical Angle of Attack)?",
              en: "What is the critical angle of attack (stall angle)?",
              answerDE: nil, answerEN: nil),
        .init(id: "p06", category: .physics,
              de: "Wie funktioniert ein Strahltriebwerk — Grundprinzip?",
              en: "How does a jet engine work — basic principle?",
              answerDE: nil, answerEN: nil),
        .init(id: "p07", category: .physics,
              de: "Was sind die vier Kräfte, die auf ein Flugzeug wirken?",
              en: "What are the four forces acting on an aircraft?",
              answerDE: nil, answerEN: nil),
        .init(id: "p08", category: .physics,
              de: "Was bewirkt Vereisung an Tragflächen?",
              en: "What effect does icing have on wings?",
              answerDE: nil, answerEN: nil),
        .init(id: "p09", category: .physics,
              de: "Was ist Drehmoment (Torque) und wie beeinflusst es ein Propellerflugzeug?",
              en: "What is torque and how does it affect a propeller aircraft?",
              answerDE: nil, answerEN: nil),
        .init(id: "p10", category: .physics,
              de: "Warum ist Hypoxie in großer Höhe gefährlich?",
              en: "Why is hypoxia dangerous at high altitude?",
              answerDE: nil, answerEN: nil),
        .init(id: "p11", category: .physics,
              de: "Erkläre den Unterschied zwischen Propeller und Turbofan-Triebwerk.",
              en: "Explain the difference between a propeller and a turbofan engine.",
              answerDE: nil, answerEN: nil),
        .init(id: "p12", category: .physics,
              de: "Was versteht man unter dem Schallmauer-Durchbruch (Mach 1)?",
              en: "What is meant by breaking the sound barrier (Mach 1)?",
              answerDE: nil, answerEN: nil),
    ]

    // ── Navigation & Wetter ──────────────────────────────────────────────────
    static let navigation: [InterviewQuestion] = [
        .init(id: "n01", category: .navigation,
              de: "Was bedeutet QNH?", en: "What does QNH mean?",
              answerDE: nil, answerEN: nil,
              requiresFlightExperience: true),
        .init(id: "n02", category: .navigation,
              de: "Was ist der Unterschied zwischen wahrer und magnetischer Missweisung?",
              en: "What is the difference between true and magnetic variation?",
              answerDE: nil, answerEN: nil,
              requiresFlightExperience: true),
        .init(id: "n03", category: .navigation,
              de: "Was versteht man unter einem Hochdruckgebiet und wie dreht der Wind auf der Nordhalbkugel?",
              en: "What is a high-pressure system and which way does wind rotate in the northern hemisphere?",
              answerDE: nil, answerEN: nil),
        .init(id: "n04", category: .navigation,
              de: "Was ist METAR und welche Informationen enthält es?",
              en: "What is a METAR and what information does it contain?",
              answerDE: nil, answerEN: nil,
              requiresFlightExperience: true),
        .init(id: "n05", category: .navigation,
              de: "Was ist der Unterschied zwischen TAF und METAR?",
              en: "Explain the difference between a TAF and a METAR.",
              answerDE: nil, answerEN: nil,
              requiresFlightExperience: true),
        .init(id: "n06", category: .navigation,
              de: "Was ist eine Inversion in der Atmosphäre?",
              en: "What is a temperature inversion in the atmosphere?",
              answerDE: nil, answerEN: nil),
        .init(id: "n07", category: .navigation,
              de: "Was bedeutet VFR und IFR?",
              en: "What do VFR and IFR mean?",
              answerDE: nil, answerEN: nil,
              requiresFlightExperience: true),
        .init(id: "n08", category: .navigation,
              de: "Was ist Cumulonimbus und warum ist er für Piloten gefährlich?",
              en: "What is a cumulonimbus cloud and why is it dangerous for pilots?",
              answerDE: nil, answerEN: nil),
        .init(id: "n09", category: .navigation,
              de: "Was sind Windscherung und Turbulenz?",
              en: "What are wind shear and turbulence?",
              answerDE: nil, answerEN: nil),
        .init(id: "n10", category: .navigation,
              de: "Warum ist das Wetter in der Höhe anders als am Boden?",
              en: "Why is the weather at altitude different from on the ground?",
              answerDE: nil, answerEN: nil),
        .init(id: "n11", category: .navigation,
              de: "Was bedeutet QFE im Gegensatz zu QNH?",
              en: "What does QFE mean compared to QNH?",
              answerDE: nil, answerEN: nil,
              requiresFlightExperience: true),
        .init(id: "n12", category: .navigation,
              de: "Wie funktioniert GPS-Navigation grundsätzlich?",
              en: "How does GPS navigation work in principle?",
              answerDE: nil, answerEN: nil),
        .init(id: "n13", category: .navigation,
              de: "Was ist Nebel und wie beeinflusst er den Flugbetrieb?",
              en: "What is fog and how does it affect flight operations?",
              answerDE: nil, answerEN: nil),
        .init(id: "n14", category: .navigation,
              de: "Was ist der Jetstream und wie entsteht er?",
              en: "What is the jet stream and how does it form?",
              answerDE: nil, answerEN: nil),
        .init(id: "n15", category: .navigation,
              de: "Was ist ein Föhn und welche Gefahren birgt er für die Luftfahrt?",
              en: "What is a Föhn wind and what hazards does it pose for aviation?",
              answerDE: nil, answerEN: nil),
    ]

    // ── Luftfahrtkunde ───────────────────────────────────────────────────────
    static let aviation: [InterviewQuestion] = [
        // Basic — no experience required
        .init(id: "a01", category: .aviation,
              de: "Warum fliegt ein Flugzeug? Erkläre es einfach.",
              en: "Why does an aircraft fly? Explain it simply.",
              answerDE: nil, answerEN: nil),
        .init(id: "a02", category: .aviation,
              de: "Welche Hauptteile hat ein Flugzeug?",
              en: "What are the main parts of an aircraft?",
              answerDE: nil, answerEN: nil),
        .init(id: "a03", category: .aviation,
              de: "Was ist der Unterschied zwischen einem Privat- und einem Linienflug?",
              en: "What is the difference between a private and a commercial flight?",
              answerDE: nil, answerEN: nil),
        .init(id: "a04", category: .aviation,
              de: "Was ist ein NOTAM?",
              en: "What is a NOTAM?",
              answerDE: nil, answerEN: nil),
        .init(id: "a05", category: .aviation,
              de: "Was regelt die EASA und was die ICAO?",
              en: "What does EASA regulate and what does ICAO regulate?",
              answerDE: nil, answerEN: nil),
        .init(id: "a06", category: .aviation,
              de: "Was ist ein Transponder und wofür wird er verwendet?",
              en: "What is a transponder and what is it used for?",
              answerDE: nil, answerEN: nil),
        .init(id: "a07", category: .aviation,
              de: "Was ist Wake Turbulence und von welchen Flugzeugkategorien geht sie aus?",
              en: "What is wake turbulence and which aircraft categories produce it?",
              answerDE: nil, answerEN: nil),
        .init(id: "a08", category: .aviation,
              de: "Was ist eine TCAS-Warnung?",
              en: "What is a TCAS alert?",
              answerDE: nil, answerEN: nil),
        .init(id: "a09", category: .aviation,
              de: "Erkläre den Unterschied zwischen Autopilot und Autothrottle.",
              en: "Explain the difference between autopilot and autothrottle.",
              answerDE: nil, answerEN: nil),
        // Advanced — requires flight experience
        .init(id: "a10", category: .aviation,
              de: "Welche Lufträume gibt es in Deutschland?",
              en: "What airspace classes exist in Germany?",
              answerDE: nil, answerEN: nil,
              requiresFlightExperience: true),
        .init(id: "a11", category: .aviation,
              de: "Was versteht man unter einem ILS-Anflug?",
              en: "What is an ILS approach?",
              answerDE: nil, answerEN: nil,
              requiresFlightExperience: true),
        .init(id: "a12", category: .aviation,
              de: "Was ist der Unterschied zwischen PPL und ATPL?",
              en: "What is the difference between a PPL and an ATPL?",
              answerDE: nil, answerEN: nil,
              requiresFlightExperience: true),
        .init(id: "a13", category: .aviation,
              de: "Welche Mindestausrüstung benötigt ein IFR-Flugzeug?",
              en: "What minimum equipment is required for IFR flight?",
              answerDE: nil, answerEN: nil,
              requiresFlightExperience: true),
    ]

    // ── Aviation English ─────────────────────────────────────────────────────
    static let english: [InterviewQuestion] = [
        .init(id: "e01", category: .english,
              de: "Was ist das phonetische Alphabet für 'P'?",
              en: "What is the phonetic alphabet for 'P'?",
              answerDE: "Papa", answerEN: "Papa"),
        .init(id: "e02", category: .english,
              de: "Was ist das phonetische Alphabet für 'M'?",
              en: "What is the phonetic alphabet for 'M'?",
              answerDE: "Mike", answerEN: "Mike"),
        .init(id: "e03", category: .english,
              de: "Was ist das phonetische Alphabet für 'W'?",
              en: "What is the phonetic alphabet for 'W'?",
              answerDE: "Whiskey", answerEN: "Whiskey"),
        .init(id: "e04", category: .english,
              de: "Was bedeutet 'Mayday' und wann wird es verwendet?",
              en: "What does 'Mayday' mean and when is it used?",
              answerDE: "Höchste Notlage — unmittelbare Lebensgefahr (franz. m'aidez)",
              answerEN: "Highest emergency — immediate danger to life (from French m'aidez)"),
        .init(id: "e05", category: .english,
              de: "Was bedeutet 'Pan Pan' im Sprechfunk?",
              en: "What does 'Pan Pan' mean on the radio?",
              answerDE: "Dringlichkeitsruf — ernste Situation, keine unmittelbare Lebensgefahr",
              answerEN: "Urgency call — serious situation, no immediate danger to life"),
        .init(id: "e06", category: .english,
              de: "Was ist das phonetische Alphabet für 'F' und 'J'?",
              en: "What is the phonetic alphabet for 'F' and 'J'?",
              answerDE: "Foxtrot, Juliet", answerEN: "Foxtrot, Juliet"),
        .init(id: "e07", category: .english,
              de: "Was bedeutet 'Roger' im Sprechfunk?",
              en: "What does 'Roger' mean on the radio?",
              answerDE: "Nachricht empfangen und verstanden",
              answerEN: "Message received and understood"),
        .init(id: "e08", category: .english,
              de: "Was bedeutet 'Wilco'?",
              en: "What does 'Wilco' mean?",
              answerDE: "Will comply — Anweisung wird ausgeführt",
              answerEN: "Will comply — instruction will be carried out"),
        .init(id: "e09", category: .english,
              de: "Was bedeutet 'Squawk 7700'?",
              en: "What does 'Squawk 7700' mean?",
              answerDE: "Notfall-Transpondercode",
              answerEN: "Emergency transponder code"),
        .init(id: "e10", category: .english,
              de: "Was bedeutet 'Hold short of runway'?",
              en: "What does 'Hold short of runway' mean?",
              answerDE: "Vor der Runway stehenbleiben — nicht einfahren",
              answerEN: "Stop before the runway threshold — do not enter"),
        .init(id: "e11", category: .english,
              de: "Was ist das phonetische Alphabet für 'A', 'B' und 'C'?",
              en: "What is the phonetic alphabet for 'A', 'B' and 'C'?",
              answerDE: "Alpha, Bravo, Charlie", answerEN: "Alpha, Bravo, Charlie"),
        .init(id: "e12", category: .english,
              de: "Was bedeutet 'Cleared for takeoff'?",
              en: "What does 'Cleared for takeoff' mean?",
              answerDE: "Startfreigabe erteilt",
              answerEN: "Permission to take off granted"),
    ]

    // ── Räumliches Denken ────────────────────────────────────────────────────
    static let spatial: [InterviewQuestion] = [
        .init(id: "s01", category: .spatial,
              de: "Welche Form entsteht, wenn du einen Würfel diagonal schneidest?",
              en: "What shape do you get when you cut a cube diagonally?",
              answerDE: "Rechteck", answerEN: "Rectangle"),
        .init(id: "s02", category: .spatial,
              de: "Ein Flugzeug dreht 90° nach rechts, dann 180° nach links — in welche Richtung fliegt es jetzt?",
              en: "An aircraft turns 90° right, then 180° left — which direction is it now facing?",
              answerDE: "90° links von der ursprünglichen Richtung", answerEN: "90° left of the original heading"),
        .init(id: "s03", category: .spatial,
              de: "Du fliegst nach Norden und drehst 135° nach rechts. Wohin fliegst du jetzt?",
              en: "You fly north and turn 135° right. What direction are you now flying?",
              answerDE: "Südost (135°)", answerEN: "Southeast (135°)"),
        .init(id: "s04", category: .spatial,
              de: "Wie viele Würfel hat ein 3×3×3-Kubus? Wie viele sind innen?",
              en: "How many cubes make up a 3×3×3 cube? How many are inside?",
              answerDE: "27 gesamt, 1 innen", answerEN: "27 total, 1 inside"),
        .init(id: "s05", category: .spatial,
              de: "Ein Kreis wird von rechts abgeflacht — welche Form entsteht?",
              en: "A circle is flattened from the right — what shape is created?",
              answerDE: "Ellipse (Oval)", answerEN: "Ellipse (Oval)"),
        .init(id: "s06", category: .spatial,
              de: "Ein Zylinder wird senkrecht zur Längsachse geschnitten — welche Form entsteht?",
              en: "A cylinder is cut perpendicular to its long axis — what shape results?",
              answerDE: "Kreis", answerEN: "Circle"),
        .init(id: "s07", category: .spatial,
              de: "Wie viele Flächen hat ein regulärer Oktaeder?",
              en: "How many faces does a regular octahedron have?",
              answerDE: "8 Flächen", answerEN: "8 faces"),
        .init(id: "s08", category: .spatial,
              de: "Du fliegst auf einem Kurs von 270° und drehst 90° nach links. Auf welchem Kurs bist du?",
              en: "You fly on a heading of 270° and turn 90° left. What is your new heading?",
              answerDE: "180°", answerEN: "180°"),
        .init(id: "s09", category: .spatial,
              de: "Stelle dir ein Flugzeug in einer steilen Linkskurve vor. Wo zeigt die linke Tragfläche?",
              en: "Imagine an aircraft in a steep left bank. Where does the left wing point?",
              answerDE: "Unten (Richtung Boden)", answerEN: "Down (toward the ground)"),
        .init(id: "s10", category: .spatial,
              de: "Ein Dreieck wird gespiegelt und dann 180° gedreht. Wie sieht es aus?",
              en: "A triangle is mirrored and then rotated 180°. How does it look?",
              answerDE: "Identisch mit dem Original", answerEN: "Identical to the original"),
        .init(id: "s11", category: .spatial,
              de: "Du siehst ein Flugzeug von oben — es fliegt nach Norden und dreht links. Was siehst du?",
              en: "You see an aircraft from above flying north and turning left. What do you see?",
              answerDE: "Es dreht nach Westen", answerEN: "It turns westward"),
        .init(id: "s12", category: .spatial,
              de: "Wie viele Ecken hat ein reguläres Ikosaeder?",
              en: "How many vertices does a regular icosahedron have?",
              answerDE: "12 Ecken", answerEN: "12 vertices"),
    ]

    // ── Motivation & Persönlichkeit ──────────────────────────────────────────
    static let personality: [InterviewQuestion] = [
        .init(id: "per01", category: .personality,
              de: "Warum möchtest du Pilot werden?",
              en: "Why do you want to become a pilot?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "War es ein bestimmtes Erlebnis, das dich zu diesem Entschluss geführt hat?",
                "Was würdest du tun, wenn du nach der Ausbildung merkst, dass es doch nicht deins ist?",
                "Sind andere Menschen in deinem Umfeld auch Piloten, oder bist du der Erste?"
              ],
              followUpsEN: [
                "Was there a specific experience that led you to this decision?",
                "What would you do if after training you realised it wasn't for you?",
                "Are other people in your circle also pilots, or are you the first?"
              ]),
        .init(id: "per02", category: .personality,
              de: "Wie gehst du mit Stress und Druck um?",
              en: "How do you handle stress and pressure?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Nenn mir ein konkretes Beispiel aus deinem Leben, wo du unter extremem Druck standest.",
                "Was würden deine engsten Freunde sagen — wie reagierst du wirklich unter Stress?",
                "Was machst du, wenn der Druck nicht nachlässt und du nicht mehr klar denken kannst?"
              ],
              followUpsEN: [
                "Give me a concrete example from your life where you were under extreme pressure.",
                "What would your closest friends say — how do you really react under stress?",
                "What do you do when the pressure doesn't let up and you can no longer think clearly?"
              ]),
        .init(id: "per03", category: .personality,
              de: "Beschreibe eine Situation, in der du eine schwierige Entscheidung treffen musstest.",
              en: "Describe a situation where you had to make a difficult decision.",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Was wäre passiert, wenn du anders entschieden hättest?",
                "Bereust du diese Entscheidung heute noch?",
                "Wie lange hast du gebraucht, um zu entscheiden — und warum so lange/kurz?"
              ],
              followUpsEN: [
                "What would have happened if you had decided differently?",
                "Do you still regret that decision today?",
                "How long did it take you to decide — and why that long/short?"
              ]),
        .init(id: "per04", category: .personality,
              de: "Wie reagierst du, wenn du einen Fehler gemacht hast?",
              en: "How do you react when you have made a mistake?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Nenn mir einen konkreten Fehler, den du gemacht hast, und was du daraus gelernt hast.",
                "Gibt es Fehler, die du bereust? Was hättest du anders gemacht?",
                "Wie gehst du damit um, wenn ein Fehler von dir Konsequenzen für andere hatte?"
              ],
              followUpsEN: [
                "Tell me a concrete mistake you made and what you learned from it.",
                "Are there mistakes you regret? What would you have done differently?",
                "How do you handle it when a mistake of yours had consequences for others?"
              ]),
        .init(id: "per05", category: .personality,
              de: "Was sind deine größten Stärken und Schwächen?",
              en: "What are your greatest strengths and weaknesses?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Kannst du ein konkretes Beispiel nennen, wo dich diese Schwäche zurückgehalten hat?",
                "Was hast du bisher aktiv getan, um an dieser Schwäche zu arbeiten?",
                "Würden deine Freunde genau dieselbe Schwäche nennen — oder etwas anderes?"
              ],
              followUpsEN: [
                "Can you give a concrete example where this weakness held you back?",
                "What have you actively done so far to work on this weakness?",
                "Would your friends name the same weakness — or something different?"
              ]),
        .init(id: "per06", category: .personality,
              de: "Wie arbeitest du in einem Team?",
              en: "How do you work in a team?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Erzähl mir von einer Situation, wo es im Team nicht gut lief — was war dein Beitrag dazu?",
                "Was machst du, wenn du anderer Meinung bist als die Mehrheit im Team?",
                "Wann fällt es dir schwer, im Team zu arbeiten?"
              ],
              followUpsEN: [
                "Tell me about a situation where things didn't go well in a team — what was your contribution to that?",
                "What do you do when you disagree with the majority of the team?",
                "When do you find it difficult to work in a team?"
              ]),
        .init(id: "per07", category: .personality,
              de: "Was würdest du tun, wenn du nach 5 Jahren Ausbildung merkst, dass du doch kein Pilot werden möchtest?",
              en: "What would you do if after 5 years of training you realised you no longer want to be a pilot?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Ist das ein realistisches Szenario für dich — oder ausgeschlossen?",
                "Was würde dich dazu bringen, aufzugeben?"
              ],
              followUpsEN: [
                "Is that a realistic scenario for you — or out of the question?",
                "What would make you give up?"
              ]),
        .init(id: "per08", category: .personality,
              de: "Wie gehst du mit Kritik von Vorgesetzten um?",
              en: "How do you handle criticism from superiors?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "War die Kritik immer berechtigt? Was hast du getan, wenn sie es nicht war?",
                "Wann fällt es dir am schwersten, Kritik anzunehmen?",
                "Gibt es eine Kritik, die dich besonders beschäftigt hat — und warum?"
              ],
              followUpsEN: [
                "Was the criticism always justified? What did you do when it wasn't?",
                "When is it hardest for you to accept criticism?",
                "Is there a piece of criticism that really got to you — and why?"
              ]),
        .init(id: "per09", category: .personality,
              de: "Wie stellst du sicher, dass du im Cockpit fokussiert und ausgeruht bist?",
              en: "How do you ensure you are focused and rested in the cockpit?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Was machst du, wenn du eine Nacht schlecht geschlafen hast und trotzdem fliegen musst?",
                "Gibt es Situationen, wo du trotz Müdigkeit leistungsfähig bleibst?"
              ],
              followUpsEN: [
                "What do you do when you slept badly and still have to fly?",
                "Are there situations where you stay capable despite fatigue?"
              ]),
        .init(id: "per10", category: .personality,
              de: "Hast du bereits Flugerfahrung? Beschreibe dein beeindruckendstes Erlebnis.",
              en: "Do you have any flight experience? Describe your most impressive experience.",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Was hat dich in diesem Moment am meisten überrascht?",
                "Hat dieses Erlebnis deine Motivation verändert?"
              ],
              followUpsEN: [
                "What surprised you most in that moment?",
                "Did that experience change your motivation?"
              ],
              requiresFlightExperience: true),
        .init(id: "per11", category: .personality,
              de: "Was motiviert dich außer dem Fliegen selbst?",
              en: "What motivates you besides flying itself?",
              answerDE: nil, answerEN: nil),
        .init(id: "per12", category: .personality,
              de: "Wo siehst du dich in 10 Jahren als Pilot?",
              en: "Where do you see yourself as a pilot in 10 years?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Ist das realistisch — was muss dafür alles klappen?",
                "Was wenn der Arbeitsmarkt dann schwierig ist?"
              ],
              followUpsEN: [
                "Is that realistic — what needs to go right?",
                "What if the job market is tough then?"
              ]),
    ]

    // ── Situatives Urteil ────────────────────────────────────────────────────
    static let judgment: [InterviewQuestion] = [
        .init(id: "j01", category: .judgment,
              de: "Du siehst ein Warnlicht im Cockpit und bist im Final. Was tust du?",
              en: "You see a warning light in the cockpit and are on final approach. What do you do?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Warum genau diese Reihenfolge? Was wäre das Schlimmste, das passieren könnte?",
                "Was wenn dein Captain sagt, es ist nicht so schlimm und ihr sollt weiterfliegen?"
              ],
              followUpsEN: [
                "Why exactly this order? What would be the worst that could happen?",
                "What if your captain says it's not serious and you should continue?"
              ]),
        .init(id: "j02", category: .judgment,
              de: "Dein Co-Pilot macht einen Fehler, den du bemerkst. Wie reagierst du?",
              en: "Your co-pilot makes an error that you notice. How do you react?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Was wenn er auf deine Korrektur defensiv reagiert?",
                "Was wenn du dir nicht 100% sicher bist, ob es wirklich ein Fehler war?"
              ],
              followUpsEN: [
                "What if he reacts defensively to your correction?",
                "What if you're not 100% sure it was really a mistake?"
              ]),
        .init(id: "j03", category: .judgment,
              de: "Du fliegst bei schlechtem Wetter und der Treibstoff reicht knapp. Was entscheidest du?",
              en: "You're flying in bad weather and fuel is running low. What is your decision?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Du hast 200 Passagiere an Bord — ändert das deine Entscheidung?",
                "Was wenn Tower dir sagt, du sollst 20 Minuten in der Warteschleife bleiben?"
              ],
              followUpsEN: [
                "You have 200 passengers on board — does that change your decision?",
                "What if tower tells you to hold for 20 minutes?"
              ]),
        .init(id: "j04", category: .judgment,
              de: "Ein Passagier wird medizinisch auffällig während des Fluges. Was ist dein Vorgehen?",
              en: "A passenger shows medical symptoms during a flight. What is your procedure?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Was wenn es kein Notfall zu sein scheint, aber du unsicher bist?",
                "Wer entscheidet letztlich — du oder der Captain?"
              ],
              followUpsEN: [
                "What if it doesn't seem like an emergency but you're uncertain?",
                "Who ultimately decides — you or the captain?"
              ]),
        .init(id: "j05", category: .judgment,
              de: "Du erhältst widersprüchliche Anweisungen vom Tower. Wie gehst du vor?",
              en: "You receive contradictory instructions from the tower. How do you proceed?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Was wenn keine Zeit zum Klären ist?",
                "Welche Anweisung hat im Zweifelsfall Vorrang?"
              ],
              followUpsEN: [
                "What if there is no time to clarify?",
                "Which instruction takes priority in case of doubt?"
              ]),
        .init(id: "j06", category: .judgment,
              de: "Kurz vor dem Abheben bemerkst du eine ungewöhnliche Vibration. Was machst du?",
              en: "Just before takeoff you notice an unusual vibration. What do you do?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Ab wann brichst du den Startlauf ab?",
                "Was wenn dein Captain sagt, es ist normal?"
              ],
              followUpsEN: [
                "At what point do you abort the takeoff run?",
                "What if your captain says it's normal?"
              ]),
        .init(id: "j07", category: .judgment,
              de: "Dein Captain entscheidet sich für eine Landung bei Bedingungen, die du für grenzwertig hältst. Was tust du?",
              en: "Your captain decides to land in conditions you consider borderline. What do you do?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Was wenn er sagt: 'Ich bin seit 20 Jahren Pilot, vertrau mir'?",
                "Gibt es Situationen, wo du als Co-Pilot das letzte Wort haben solltest?"
              ],
              followUpsEN: [
                "What if he says: 'I've been a pilot for 20 years, trust me'?",
                "Are there situations where you as co-pilot should have the final say?"
              ]),
        .init(id: "j08", category: .judgment,
              de: "Du bist übermüdet vor einem frühen Flug. Was tust du?",
              en: "You are fatigued before an early-morning flight. What do you do?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Was wenn dein Vorgesetzter sagt, es gibt keine Alternative und du musst fliegen?",
                "Wo liegt für dich persönlich die Grenze, die du nicht überschreitest?"
              ],
              followUpsEN: [
                "What if your superior says there's no alternative and you must fly?",
                "Where is your personal line that you won't cross?"
              ]),
        .init(id: "j09", category: .judgment,
              de: "Ein anderer Pilot berichtet, er habe Alkohol getrunken. Was unternimmst du?",
              en: "Another pilot reports having had alcohol. What do you do?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Was wenn es dein bester Freund ist?",
                "Was wenn er sagt, es war nur ein kleines Glas und er fühlt sich fit?"
              ],
              followUpsEN: [
                "What if it's your best friend?",
                "What if he says it was just one small drink and he feels fine?"
              ]),
        .init(id: "j10", category: .judgment,
              de: "Du bemerkst beim Briefing, dass eine wichtige Information im Flugplan fehlt. Was tust du?",
              en: "During briefing you notice that important information is missing from the flight plan. What do you do?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Was wenn der Abflug in 10 Minuten ist?",
                "Wer ist verantwortlich für den Fehler, und spielt das eine Rolle?"
              ],
              followUpsEN: [
                "What if the departure is in 10 minutes?",
                "Who is responsible for the error, and does it matter?"
              ]),
        .init(id: "j11", category: .judgment,
              de: "Du fliegst nachts und verlierst kurz die Orientierung. Was sind deine ersten Schritte?",
              en: "You are flying at night and briefly lose your orientation. What are your first steps?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Was machst du zuerst — Instrumente oder aus dem Fenster schauen?",
                "Wann rufst du einen Mayday aus?"
              ],
              followUpsEN: [
                "What do you do first — instruments or look out the window?",
                "When do you declare a Mayday?"
              ],
              excludedLicenses: [.ultralight, .lapl, .tmg, .paramotor]),
        .init(id: "j12", category: .judgment,
              de: "Die Kabine verliert unerwartet an Druck. Welche Sofortmaßnahmen leitest du ein?",
              en: "The cabin unexpectedly loses pressure. What immediate actions do you take?",
              answerDE: nil, answerEN: nil,
              followUpsDE: [
                "Wie viel Zeit hast du, bevor die Sauerstoffmasken fallen sollten?",
                "Was wenn der Notabstieg mit dem Ausweichen eines anderen Flugzeuges kollidiert?"
              ],
              followUpsEN: [
                "How much time do you have before oxygen masks should drop?",
                "What if the emergency descent conflicts with avoiding another aircraft?"
              ]),
    ]
}
