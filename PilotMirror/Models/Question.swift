import Foundation

enum QuestionType: String, Codable {
    case traitSelection
    case forcedChoice
    case ratingScale
    case openText
}

struct Question: Identifiable, Codable {
    let id: String
    let type: QuestionType
    let text: String           // German — third-person ("diese Person"), used for respondent survey & AI
    let textEN: String?        // English — third-person
    let textSelf: String?      // German — first-person ("du"), shown only in self-assessment
    let textSelfEN: String?    // English — first-person ("you"), shown only in self-assessment
    let options: [String]?     // Stored in German (canonical)
    let optionsEN: [String]?   // English display labels (parallel to options)
    let scaleMin: Int?
    let scaleMax: Int?
    let scaleLabel: String?
    let placeholder: String?
    let placeholderEN: String?
    let section: Int
    let sectionTitle: String   // German
    let sectionTitleEN: String // English

    func displayText(isGerman: Bool) -> String { isGerman ? text : (textEN ?? text) }
    func displayPlaceholder(isGerman: Bool) -> String? { isGerman ? placeholder : (placeholderEN ?? placeholder) }
    func displaySectionTitle(isGerman: Bool) -> String { isGerman ? sectionTitle : sectionTitleEN }
    func displayOptions(isGerman: Bool) -> [String]? {
        isGerman ? options : (optionsEN ?? options)
    }

    /// Returns display text personalized for the survey mode.
    /// - selfAssessment: uses "Du"-form (textSelf / textSelfEN)
    /// - respondent: replaces "diese/r Person" with the candidate's first name
    func displayText(mode: SurveyMode, candidateName: String? = nil, isGerman: Bool) -> String {
        switch mode {
        case .selfAssessment:
            if isGerman { return textSelf ?? text }
            return textSelfEN ?? textEN ?? text
        case .respondent:
            let base = isGerman ? text : (textEN ?? text)
            guard let name = candidateName, !name.isEmpty else { return base }
            return base
                .replacingOccurrences(of: "Diese Person", with: name)
                .replacingOccurrences(of: "diese Person", with: name)
                .replacingOccurrences(of: "dieser Person", with: name)
                .replacingOccurrences(of: "This person", with: name)
                .replacingOccurrences(of: "this person", with: name)
        }
    }
}

extension Question {

    // MARK: - Helper for creating questions with textSelf shorthand
    private static func q(
        id: String, type: QuestionType,
        text: String, textEN: String? = nil,
        textSelf: String? = nil, textSelfEN: String? = nil,
        options: [String]? = nil, optionsEN: [String]? = nil,
        scaleMin: Int? = nil, scaleMax: Int? = nil, scaleLabel: String? = nil,
        placeholder: String? = nil, placeholderEN: String? = nil,
        section: Int, sectionTitle: String, sectionTitleEN: String
    ) -> Question {
        Question(id: id, type: type, text: text, textEN: textEN,
                 textSelf: textSelf, textSelfEN: textSelfEN,
                 options: options, optionsEN: optionsEN,
                 scaleMin: scaleMin, scaleMax: scaleMax, scaleLabel: scaleLabel,
                 placeholder: placeholder, placeholderEN: placeholderEN,
                 section: section, sectionTitle: sectionTitle, sectionTitleEN: sectionTitleEN)
    }

    static let surveyQuestions: [Question] = [

        // MARK: Section 1 — Persönlichkeit
        q(id: "q1", type: .traitSelection,
          text: "Welche Eigenschaften beschreiben diese Person? Alle zutreffenden auswählen.",
          textEN: "Which words describe this person? Select all that apply.",
          textSelf: "Welche Eigenschaften beschreiben dich am besten? Alle zutreffenden auswählen.",
          textSelfEN: "Which words describe you best? Select all that apply.",
          options: ["ruhig", "analytisch", "strukturiert", "selbstsicher", "teamorientiert",
                    "kommunikativ", "verantwortungsbewusst", "belastbar", "empathisch",
                    "führungsstark", "introvertiert", "dominant", "impulsiv",
                    "konfliktscheu", "ungeduldig", "unorganisiert"],
          optionsEN: ["calm", "analytical", "structured", "confident", "team-oriented",
                      "communicative", "responsible", "resilient", "empathetic",
                      "strong leader", "introverted", "dominant", "impulsive",
                      "conflict-avoidant", "impatient", "disorganised"],
          section: 1, sectionTitle: "Persönlichkeit", sectionTitleEN: "Personality"),

        // MARK: Section 2 — Entscheidungsstil
        q(id: "q2", type: .forcedChoice,
          text: "Diese Person entscheidet eher:",
          textEN: "This person tends to decide:",
          textSelf: "Du entscheidest eher:",
          textSelfEN: "You tend to decide:",
          options: ["Schnell und intuitiv", "Nach sorgfältiger Analyse"],
          optionsEN: ["Quickly and intuitively", "After careful analysis"],
          section: 2, sectionTitle: "Entscheidungsstil", sectionTitleEN: "Decision Style"),

        q(id: "q3", type: .forcedChoice,
          text: "In Gruppen tendiert diese Person dazu:",
          textEN: "In groups, this person tends to:",
          textSelf: "In Gruppen tendierst du dazu:",
          textSelfEN: "In groups, you tend to:",
          options: ["häufig die Führung zu übernehmen",
                    "aktiv Ideen einzubringen",
                    "zunächst zu beobachten und später zu sprechen"],
          optionsEN: ["take the lead frequently",
                      "actively contribute ideas",
                      "observe first and speak later"],
          section: 2, sectionTitle: "Entscheidungsstil", sectionTitleEN: "Decision Style"),

        q(id: "q4", type: .forcedChoice,
          text: "Wenn etwas schiefläuft, reagiert diese Person:",
          textEN: "When something goes wrong, this person reacts:",
          textSelf: "Wenn etwas schiefläuft, reagierst du:",
          textSelfEN: "When something goes wrong, you react:",
          options: ["Ruhig & lösungsorientiert", "Gestresst aber funktional", "Emotional/frustriert"],
          optionsEN: ["Calm and solution-focused", "Stressed but functional", "Emotionally/frustrated"],
          section: 2, sectionTitle: "Entscheidungsstil", sectionTitleEN: "Decision Style"),

        q(id: "q4b", type: .forcedChoice,
          text: "Wenn Meinungsverschiedenheiten entstehen, reagiert diese Person eher:",
          textEN: "When disagreements arise, this person tends to:",
          textSelf: "Wenn Meinungsverschiedenheiten entstehen, reagierst du eher:",
          textSelfEN: "When disagreements arise, you tend to:",
          options: ["Konflikte vermeiden", "Zwischen den Positionen vermitteln", "Die eigene Position aktiv vertreten"],
          optionsEN: ["Avoid conflict", "Mediate between positions", "Actively defend their own position"],
          section: 2, sectionTitle: "Entscheidungsstil", sectionTitleEN: "Decision Style"),

        // MARK: Section 3 — Bewertungen
        q(id: "q5", type: .ratingScale,
          text: "Teamfähigkeit", textEN: "Teamwork",
          textSelf: "Teamfähigkeit", textSelfEN: "Teamwork",
          scaleMin: 1, scaleMax: 5,
          section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings"),

        q(id: "q6", type: .ratingScale,
          text: "Stressresistenz", textEN: "Stress Resistance",
          textSelf: "Stressresistenz", textSelfEN: "Stress Resistance",
          scaleMin: 1, scaleMax: 5,
          section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings"),

        q(id: "q7", type: .ratingScale,
          text: "Verantwortungsbewusstsein", textEN: "Responsibility",
          textSelf: "Verantwortungsbewusstsein", textSelfEN: "Responsibility",
          scaleMin: 1, scaleMax: 5,
          section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings"),

        q(id: "q8", type: .ratingScale,
          text: "Kommunikation", textEN: "Communication",
          textSelf: "Kommunikation", textSelfEN: "Communication",
          scaleMin: 1, scaleMax: 5,
          section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings"),

        q(id: "q9", type: .ratingScale,
          text: "Zuverlässigkeit", textEN: "Reliability",
          textSelf: "Zuverlässigkeit", textSelfEN: "Reliability",
          scaleMin: 1, scaleMax: 5,
          section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings"),

        q(id: "q10_org", type: .ratingScale,
          text: "Wie strukturiert arbeitet diese Person?", textEN: "How organised is this person in their work?",
          textSelf: "Wie strukturiert arbeitest du?", textSelfEN: "How organised are you in your work?",
          scaleMin: 1, scaleMax: 5,
          section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings"),

        // MARK: Section 4 — Stärken
        q(id: "q10", type: .openText,
          text: "Was ist eine der größten Stärken dieser Person?",
          textEN: "What is one of this person's greatest strengths?",
          textSelf: "Was ist eine deiner größten Stärken?",
          textSelfEN: "What is one of your greatest strengths?",
          placeholder: "z.B. bleibt in stressigen Situationen ruhig und strukturiert…",
          placeholderEN: "e.g. stays calm and structured in stressful situations…",
          section: 4, sectionTitle: "Stärken", sectionTitleEN: "Strengths"),

        q(id: "q11", type: .openText,
          text: "Wofür wird diese Person von anderen besonders geschätzt?",
          textEN: "What is this person particularly appreciated for by others?",
          textSelf: "Wofür wirst du von anderen besonders geschätzt?",
          textSelfEN: "What are you particularly appreciated for by others?",
          placeholder: "z.B. ist immer gut vorbereitet, motiviert andere…",
          placeholderEN: "e.g. always well-prepared, motivates others…",
          section: 4, sectionTitle: "Stärken", sectionTitleEN: "Strengths"),

        q(id: "q12", type: .openText,
          text: "In welchen Situationen hilft diese Person einer Gruppe besonders?",
          textEN: "In which situations does this person help a group most?",
          textSelf: "In welchen Situationen hilfst du einer Gruppe besonders?",
          textSelfEN: "In which situations do you help a group most?",
          placeholder: "z.B. in Konfliktsituationen, bei der Planung, unter Druck…",
          placeholderEN: "e.g. in conflict situations, during planning, under pressure…",
          section: 4, sectionTitle: "Stärken", sectionTitleEN: "Strengths"),

        // MARK: Section 5 — Schwächen
        q(id: "q13", type: .openText,
          text: "Wo hat diese Person im Alltag Entwicklungspotenzial?",
          textEN: "Where does this person have room to develop in everyday life?",
          textSelf: "Wo hast du im Alltag Entwicklungspotenzial?",
          textSelfEN: "Where do you have room to develop in everyday life?",
          placeholder: "z.B. könnte strukturierter planen, mehr auf andere eingehen…",
          placeholderEN: "e.g. could plan more systematically, be more attentive to others…",
          section: 5, sectionTitle: "Schwächen", sectionTitleEN: "Weaknesses"),

        q(id: "q14", type: .openText,
          text: "Gibt es Verhaltensweisen dieser Person, die manchmal schwierig sein können?",
          textEN: "Are there behaviours of this person that can sometimes be difficult?",
          textSelf: "Gibt es Verhaltensweisen bei dir, die manchmal schwierig sein können?",
          textSelfEN: "Are there behaviours of yours that can sometimes be difficult?",
          placeholder: "z.B. reagiert manchmal ungeduldig, wenn Dinge nicht nach Plan laufen…",
          placeholderEN: "e.g. sometimes reacts impatiently when things don't go as planned…",
          section: 5, sectionTitle: "Schwächen", sectionTitleEN: "Weaknesses"),

        q(id: "q15", type: .openText,
          text: "Welches Verhalten dieser Person kann in Gruppen gelegentlich problematisch sein?",
          textEN: "Which of this person's behaviours can occasionally be problematic in groups?",
          textSelf: "Welches deiner eigenen Verhaltensweisen kann in Gruppen gelegentlich problematisch sein?",
          textSelfEN: "Which of your own behaviours can occasionally be problematic in groups?",
          placeholder: "z.B. übernimmt zu schnell das Wort, hört nicht aktiv zu…",
          placeholderEN: "e.g. takes the floor too quickly, doesn't listen actively…",
          section: 5, sectionTitle: "Schwächen", sectionTitleEN: "Weaknesses"),

        // MARK: Section 6 — Verhalten & Außenwirkung
        q(id: "q16", type: .openText,
          text: "Gibt es negative Verhaltensweisen im Alltag, die dieser Person wahrscheinlich nicht bewusst sind?",
          textEN: "Are there negative everyday behaviors this person is probably unaware of?",
          textSelf: "Gibt es Verhaltensweisen bei dir, die dir selbst vielleicht nicht bewusst sind?",
          textSelfEN: "Are there behaviors in yourself that you may not be aware of?",
          placeholder: "z.B. unterbricht andere im Gespräch, reagiert defensiv auf Kritik…",
          placeholderEN: "e.g. interrupts others, reacts defensively to criticism…",
          section: 6, sectionTitle: "Verhalten & Außenwirkung", sectionTitleEN: "Behaviour & Perception"),

        q(id: "q17", type: .openText,
          text: "Wie reagiert diese Person, wenn sie kritisiert wird oder Fehler macht?",
          textEN: "How does this person react when criticised or when they make a mistake?",
          textSelf: "Wie reagierst du, wenn du kritisiert wirst oder Fehler machst?",
          textSelfEN: "How do you react when you are criticised or make a mistake?",
          placeholder: "z.B. nimmt Feedback gut an / wird defensiv / zieht sich zurück…",
          placeholderEN: "e.g. takes feedback well / becomes defensive / withdraws…",
          section: 6, sectionTitle: "Verhalten & Außenwirkung", sectionTitleEN: "Behaviour & Perception"),

        q(id: "q18", type: .openText,
          text: "Wenn diese Person an einem anspruchsvollen Auswahlverfahren teilnimmt – welches Verhalten könnte ihr besonders helfen oder besonders im Weg stehen?",
          textEN: "If this person were to take part in a demanding selection process – which of their behaviours could help or hinder them the most?",
          textSelf: "Wenn du an einem anspruchsvollen Auswahlverfahren teilnimmst – welches deiner Verhaltensweisen könnte dir besonders helfen oder im Weg stehen?",
          textSelfEN: "If you were to take part in a demanding selection process – which of your behaviours could help or hinder you the most?",
          placeholder: "z.B. wirkt in unbekannten Gruppen zunächst distanziert, obwohl ein starker Teamplayer…",
          placeholderEN: "e.g. initially appears distant in new groups, though a strong team player…",
          section: 6, sectionTitle: "Verhalten & Außenwirkung", sectionTitleEN: "Behaviour & Perception"),
    ]

    // MARK: - License-specific questions for self-assessment (Section 7)

    static func licenseSpecificQuestions(for licenses: [User.FlightLicense]) -> [Question] {
        var result: [Question] = []
        let sec = 7
        let titleDE = "Fliegerfahrung"
        let titleEN = "Flying Experience"

        if licenses.contains(.ppl) || licenses.contains(.lapl) || licenses.contains(.tmg) {
            result += [
                q(id: "ql1", type: .openText,
                  text: "Wie viele Flugstunden hast du bisher absolviert und auf welchen Mustern?",
                  textEN: "How many flight hours have you completed and on which aircraft types?",
                  textSelf: "Wie viele Flugstunden hast du bisher absolviert und auf welchen Mustern?",
                  textSelfEN: "How many flight hours have you completed and on which aircraft types?",
                  placeholder: "z.B. 90 Stunden auf C172, 15 Stunden auf DR400…",
                  placeholderEN: "e.g. 90 hours on C172, 15 hours on DR400…",
                  section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN),
                q(id: "ql2", type: .openText,
                  text: "Wie bereitest du einen Überlandflug vor? (z.B. PLOG, Wetter, NOTAM, Flugplan)",
                  textEN: "How do you prepare a cross-country flight? (e.g. PLOG, weather, NOTAM, flight plan)",
                  textSelf: "Wie bereitest du einen Überlandflug vor? (z.B. PLOG, Wetter, NOTAM, Flugplan)",
                  textSelfEN: "How do you prepare a cross-country flight? (e.g. PLOG, weather, NOTAM, flight plan)",
                  placeholder: "Beschreibe deinen typischen Vorbereitungsprozess…",
                  placeholderEN: "Describe your typical preparation process…",
                  section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN),
                q(id: "ql3", type: .openText,
                  text: "Beschreibe eine herausfordernde Situation im Cockpit und wie du damit umgegangen bist.",
                  textEN: "Describe a challenging situation in the cockpit and how you handled it.",
                  textSelf: "Beschreibe eine herausfordernde Situation im Cockpit und wie du damit umgegangen bist.",
                  textSelfEN: "Describe a challenging situation in the cockpit and how you handled it.",
                  placeholder: "z.B. unerwartetes Wetter, technisches Problem, schwieriger Anflug…",
                  placeholderEN: "e.g. unexpected weather, technical issue, difficult approach…",
                  section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN),
                q(id: "ql4", type: .openText,
                  text: "Was verstehst du unter CRM (Crew Resource Management) und wie lebst du es?",
                  textEN: "What do you understand by CRM (Crew Resource Management) and how do you apply it?",
                  textSelf: "Was verstehst du unter CRM (Crew Resource Management) und wie lebst du es?",
                  textSelfEN: "What do you understand by CRM (Crew Resource Management) and how do you apply it?",
                  placeholder: "z.B. offene Kommunikation, gegenseitige Überwachung, klare Aufgabenverteilung…",
                  placeholderEN: "e.g. open communication, mutual monitoring, clear task allocation…",
                  section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN),
            ]
        }
        if licenses.contains(.ultralight) {
            result += [
                q(id: "ql_ul1", type: .openText,
                  text: "Welche Besonderheiten müssen UL-Piloten bei der Flugplanung beachten?",
                  textEN: "What special considerations must ultralight pilots keep in mind when flight planning?",
                  textSelf: "Welche Besonderheiten müssen UL-Piloten bei der Flugplanung beachten?",
                  textSelfEN: "What special considerations must ultralight pilots keep in mind when flight planning?",
                  placeholder: "z.B. Windlimits, Luftraum, Beschränkungen…",
                  placeholderEN: "e.g. wind limits, airspace, restrictions…",
                  section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN),
                q(id: "ql_ul2", type: .openText,
                  text: "Beschreibe eine Situation, in der du als UL-Pilot eine schnelle Entscheidung treffen musstest.",
                  textEN: "Describe a situation as an ultralight pilot where you had to make a quick decision.",
                  textSelf: "Beschreibe eine Situation, in der du als UL-Pilot eine schnelle Entscheidung treffen musstest.",
                  textSelfEN: "Describe a situation as an ultralight pilot where you had to make a quick decision.",
                  placeholder: "z.B. plötzliche Wetteränderung, Notlandung…",
                  placeholderEN: "e.g. sudden weather change, emergency landing…",
                  section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN),
            ]
        }
        if licenses.contains(.paramotor) {
            result += [
                q(id: "ql_pm1", type: .openText,
                  text: "Welche Wetterbedingungen prüfst du vor einem Paramotorflug?",
                  textEN: "Which weather conditions do you check before a paramotor flight?",
                  textSelf: "Welche Wetterbedingungen prüfst du vor einem Paramotorflug?",
                  textSelfEN: "Which weather conditions do you check before a paramotor flight?",
                  placeholder: "z.B. Wind, Thermik, Sicht, Niederschlag…",
                  placeholderEN: "e.g. wind, thermals, visibility, precipitation…",
                  section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN),
            ]
        }
        if licenses.contains(.other) {
            result += [
                q(id: "ql_oth1", type: .openText,
                  text: "Beschreibe deine bisherige Flugerfahrung und welche Lektionen du daraus mitgenommen hast.",
                  textEN: "Describe your flying experience so far and what lessons you have taken from it.",
                  textSelf: "Beschreibe deine bisherige Flugerfahrung und welche Lektionen du daraus mitgenommen hast.",
                  textSelfEN: "Describe your flying experience so far and what lessons you have taken from it.",
                  placeholder: "z.B. Art der Lizenz, Erfahrungsbereich, wichtigste Lernerfahrungen…",
                  placeholderEN: "e.g. type of licence, experience area, key learning experiences…",
                  section: sec, sectionTitle: titleDE, sectionTitleEN: titleEN),
            ]
        }
        return result
    }
}
