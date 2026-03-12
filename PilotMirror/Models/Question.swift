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
    let text: String           // German
    let textEN: String?        // English
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
}

extension Question {
    static let surveyQuestions: [Question] = [

        // Section 1
        Question(
            id: "q1", type: .traitSelection,
            text: "Welche Eigenschaften beschreiben diese Person? Alle zutreffenden auswählen.",
            textEN: "Which words describe this person? Select all that apply.",
            options: ["ruhig", "analytisch", "selbstsicher", "teamorientiert", "verantwortungsbewusst",
                      "strukturiert", "bedachtsam", "spontan", "dominant", "zurückhaltend",
                      "empathisch", "entscheidungsfreudig"],
            optionsEN: ["calm", "analytical", "confident", "team-oriented", "responsible",
                        "structured", "careful", "spontaneous", "dominant", "reserved",
                        "empathetic", "decisive"],
            scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: nil, placeholderEN: nil,
            section: 1, sectionTitle: "Persönlichkeit", sectionTitleEN: "Personality"
        ),

        // Section 2
        Question(
            id: "q2", type: .forcedChoice,
            text: "Diese Person entscheidet eher:",
            textEN: "This person tends to decide:",
            options: ["Schnell und intuitiv", "Nach sorgfältiger Analyse"],
            optionsEN: ["Quickly and intuitively", "After careful analysis"],
            scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: nil, placeholderEN: nil,
            section: 2, sectionTitle: "Entscheidungsstil", sectionTitleEN: "Decision Style"
        ),
        Question(
            id: "q3", type: .forcedChoice,
            text: "In Gruppen tendiert diese Person dazu:",
            textEN: "In groups, this person tends to:",
            options: ["Die Diskussion zu führen", "Ideen einzubringen", "Erst zu beobachten"],
            optionsEN: ["Lead the discussion", "Contribute ideas", "Observe first"],
            scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: nil, placeholderEN: nil,
            section: 2, sectionTitle: "Entscheidungsstil", sectionTitleEN: "Decision Style"
        ),
        Question(
            id: "q4", type: .forcedChoice,
            text: "Wenn etwas schiefläuft, reagiert diese Person:",
            textEN: "When something goes wrong, this person reacts:",
            options: ["Ruhig & lösungsorientiert", "Gestresst aber funktional", "Emotional/frustriert"],
            optionsEN: ["Calm and solution-focused", "Stressed but functional", "Emotionally/frustrated"],
            scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: nil, placeholderEN: nil,
            section: 2, sectionTitle: "Entscheidungsstil", sectionTitleEN: "Decision Style"
        ),

        // Section 3
        Question(id: "q5", type: .ratingScale, text: "Teamfähigkeit", textEN: "Teamwork", options: nil, optionsEN: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, placeholder: nil, placeholderEN: nil, section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings"),
        Question(id: "q6", type: .ratingScale, text: "Stressresistenz", textEN: "Stress Resistance", options: nil, optionsEN: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, placeholder: nil, placeholderEN: nil, section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings"),
        Question(id: "q7", type: .ratingScale, text: "Verantwortungsbewusstsein", textEN: "Responsibility", options: nil, optionsEN: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, placeholder: nil, placeholderEN: nil, section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings"),
        Question(id: "q8", type: .ratingScale, text: "Kommunikation", textEN: "Communication", options: nil, optionsEN: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, placeholder: nil, placeholderEN: nil, section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings"),
        Question(id: "q9", type: .ratingScale, text: "Zuverlässigkeit", textEN: "Reliability", options: nil, optionsEN: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, placeholder: nil, placeholderEN: nil, section: 3, sectionTitle: "Bewertungen", sectionTitleEN: "Ratings"),

        // Section 4 — Stärken
        Question(id: "q10", type: .openText,
            text: "Stärke 1: Was kann diese Person besonders gut?",
            textEN: "Strength 1: What is this person particularly good at?",
            options: nil, optionsEN: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. hört gut zu, bleibt in Konflikten sachlich…",
            placeholderEN: "e.g. listens well, stays calm in conflicts…",
            section: 4, sectionTitle: "Stärken", sectionTitleEN: "Strengths"),
        Question(id: "q11", type: .openText,
            text: "Stärke 2: Wofür wird diese Person von anderen geschätzt?",
            textEN: "Strength 2: What is this person appreciated for by others?",
            options: nil, optionsEN: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. ist immer gut vorbereitet, motiviert andere…",
            placeholderEN: "e.g. always well-prepared, motivates others…",
            section: 4, sectionTitle: "Stärken", sectionTitleEN: "Strengths"),
        Question(id: "q12", type: .openText,
            text: "Stärke 3: In welchen Situationen zeigt diese Person ihr Bestes?",
            textEN: "Strength 3: When does this person perform at their best?",
            options: nil, optionsEN: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. unter Druck, bei komplexen Problemen…",
            placeholderEN: "e.g. under pressure, with complex problems…",
            section: 4, sectionTitle: "Stärken", sectionTitleEN: "Strengths"),

        // Section 5 — Schwächen
        Question(id: "q13", type: .openText,
            text: "Schwäche 1: Wo hat diese Person im Alltag Nachholbedarf?",
            textEN: "Weakness 1: Where does this person have room to grow?",
            options: nil, optionsEN: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. wird ungeduldig, wenn Dinge nicht nach Plan laufen…",
            placeholderEN: "e.g. gets impatient when things don't go as planned…",
            section: 5, sectionTitle: "Schwächen", sectionTitleEN: "Weaknesses"),
        Question(id: "q14", type: .openText,
            text: "Schwäche 2: Was kostet diese Person manchmal Sympathien?",
            textEN: "Weakness 2: What sometimes costs this person goodwill?",
            options: nil, optionsEN: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. redet manchmal zu viel ohne zuzuhören…",
            placeholderEN: "e.g. sometimes talks too much without listening…",
            section: 5, sectionTitle: "Schwächen", sectionTitleEN: "Weaknesses"),
        Question(id: "q15", type: .openText,
            text: "Schwäche 3: Welches Verhalten dieser Person nervt dich manchmal?",
            textEN: "Weakness 3: What behavior of this person occasionally bothers you?",
            options: nil, optionsEN: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. gibt ungern Fehler zu, zieht Entscheidungen in die Länge…",
            placeholderEN: "e.g. reluctant to admit mistakes, delays decisions…",
            section: 5, sectionTitle: "Schwächen", sectionTitleEN: "Weaknesses"),

        // Section 6 — Verhalten & Außenwirkung
        Question(id: "q16", type: .openText,
            text: "Gibt es negative Verhaltensweisen im Alltag, die dieser Person wahrscheinlich nicht bewusst sind?",
            textEN: "Are there negative everyday behaviors this person is probably unaware of?",
            options: nil, optionsEN: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. unterbricht andere im Gespräch, reagiert defensiv auf Kritik…",
            placeholderEN: "e.g. interrupts others, reacts defensively to criticism…",
            section: 6, sectionTitle: "Verhalten & Außenwirkung", sectionTitleEN: "Behaviour & Perception"),
        Question(id: "q17", type: .openText,
            text: "Wie reagiert diese Person, wenn sie kritisiert wird oder Fehler macht?",
            textEN: "How does this person react when criticised or when they make a mistake?",
            options: nil, optionsEN: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. nimmt Feedback gut an / wird defensiv / zieht sich zurück…",
            placeholderEN: "e.g. takes feedback well / becomes defensive / withdraws…",
            section: 6, sectionTitle: "Verhalten & Außenwirkung", sectionTitleEN: "Behaviour & Perception"),
        Question(id: "q18", type: .openText,
            text: "Was sollte der Kandidat über seine Wirkung auf andere wissen — etwas, das ihm im Assessment nützen oder schaden könnte?",
            textEN: "What should the candidate know about how they come across — something that could help or hurt them in an assessment?",
            options: nil, optionsEN: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. wirkt in unbekannten Gruppen zunächst distanziert, obwohl er ein starker Teamplayer ist…",
            placeholderEN: "e.g. initially appears distant in new groups, though they are a strong team player…",
            section: 6, sectionTitle: "Verhalten & Außenwirkung", sectionTitleEN: "Behaviour & Perception"),
    ]
}
