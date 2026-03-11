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
    let text: String
    let options: [String]?
    let scaleMin: Int?
    let scaleMax: Int?
    let scaleLabel: String?
    let placeholder: String?
    let section: Int
    let sectionTitle: String
}

extension Question {
    static let surveyQuestions: [Question] = [

        // Section 1 — Eigenschaften
        Question(
            id: "q1",
            type: .traitSelection,
            text: "Welche Eigenschaften beschreiben diese Person? Alle zutreffenden auswählen.",
            options: ["ruhig", "analytisch", "selbstsicher", "teamorientiert", "verantwortungsbewusst",
                      "strukturiert", "bedachtsam", "spontan", "dominant", "zurückhaltend",
                      "empathisch", "entscheidungsfreudig"],
            scaleMin: nil, scaleMax: nil, scaleLabel: nil, placeholder: nil,
            section: 1, sectionTitle: "Persönlichkeit"
        ),

        // Section 2 — Entscheidungsstil
        Question(
            id: "q2",
            type: .forcedChoice,
            text: "Diese Person entscheidet eher:",
            options: ["Schnell und intuitiv", "Nach sorgfältiger Analyse"],
            scaleMin: nil, scaleMax: nil, scaleLabel: nil, placeholder: nil,
            section: 2, sectionTitle: "Entscheidungsstil"
        ),
        Question(
            id: "q3",
            type: .forcedChoice,
            text: "In Gruppen tendiert diese Person dazu:",
            options: ["Die Diskussion zu führen", "Ideen einzubringen", "Erst zu beobachten"],
            scaleMin: nil, scaleMax: nil, scaleLabel: nil, placeholder: nil,
            section: 2, sectionTitle: "Entscheidungsstil"
        ),
        Question(
            id: "q4",
            type: .forcedChoice,
            text: "Wenn etwas schiefläuft, reagiert diese Person:",
            options: ["Ruhig & lösungsorientiert", "Gestresst aber funktional", "Emotional/frustriert"],
            scaleMin: nil, scaleMax: nil, scaleLabel: nil, placeholder: nil,
            section: 2, sectionTitle: "Entscheidungsstil"
        ),

        // Section 3 — Bewertungen
        Question(id: "q5", type: .ratingScale, text: "Teamfähigkeit", options: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, placeholder: nil, section: 3, sectionTitle: "Bewertungen"),
        Question(id: "q6", type: .ratingScale, text: "Stressresistenz", options: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, placeholder: nil, section: 3, sectionTitle: "Bewertungen"),
        Question(id: "q7", type: .ratingScale, text: "Verantwortungsbewusstsein", options: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, placeholder: nil, section: 3, sectionTitle: "Bewertungen"),
        Question(id: "q8", type: .ratingScale, text: "Kommunikation", options: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, placeholder: nil, section: 3, sectionTitle: "Bewertungen"),
        Question(id: "q9", type: .ratingScale, text: "Zuverlässigkeit", options: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, placeholder: nil, section: 3, sectionTitle: "Bewertungen"),

        // Section 4 — Stärken (mind. 3)
        Question(
            id: "q10",
            type: .openText,
            text: "Stärke 1: Was kann diese Person besonders gut?",
            options: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. hört gut zu, bleibt in Konflikten sachlich…",
            section: 4, sectionTitle: "Stärken"
        ),
        Question(
            id: "q11",
            type: .openText,
            text: "Stärke 2: Wofür wird diese Person von anderen geschätzt?",
            options: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. ist immer gut vorbereitet, motiviert andere…",
            section: 4, sectionTitle: "Stärken"
        ),
        Question(
            id: "q12",
            type: .openText,
            text: "Stärke 3: In welchen Situationen zeigt diese Person ihr Bestes?",
            options: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. unter Druck, bei komplexen Problemen…",
            section: 4, sectionTitle: "Stärken"
        ),

        // Section 5 — Schwächen (mind. 3, allgemein)
        Question(
            id: "q13",
            type: .openText,
            text: "Schwäche 1: Wo hat diese Person im Alltag Nachholbedarf?",
            options: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. wird ungeduldig, wenn Dinge nicht nach Plan laufen…",
            section: 5, sectionTitle: "Schwächen"
        ),
        Question(
            id: "q14",
            type: .openText,
            text: "Schwäche 2: Was kostet diese Person manchmal Sympathien?",
            options: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. redet manchmal zu viel ohne zuzuhören…",
            section: 5, sectionTitle: "Schwächen"
        ),
        Question(
            id: "q15",
            type: .openText,
            text: "Schwäche 3: Welches Verhalten dieser Person nervt dich manchmal?",
            options: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. gibt ungern Fehler zu, zieht Entscheidungen in die Länge…",
            section: 5, sectionTitle: "Schwächen"
        ),

        // Section 6 — Verhalten & Außenwirkung
        Question(
            id: "q16",
            type: .openText,
            text: "Gibt es negative Verhaltensweisen im Alltag, die dieser Person wahrscheinlich nicht bewusst sind?",
            options: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. unterbricht andere im Gespräch, reagiert defensiv auf Kritik…",
            section: 6, sectionTitle: "Verhalten & Außenwirkung"
        ),
        Question(
            id: "q17",
            type: .openText,
            text: "Wie reagiert diese Person, wenn sie kritisiert wird oder Fehler macht?",
            options: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. nimmt Feedback gut an / wird defensiv / zieht sich zurück…",
            section: 6, sectionTitle: "Verhalten & Außenwirkung"
        ),
        Question(
            id: "q18",
            type: .openText,
            text: "Was sollte der Kandidat über seine Wirkung auf andere wissen — etwas, das ihm im Assessment nützen oder schaden könnte?",
            options: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            placeholder: "z.B. wirkt in unbekannten Gruppen zunächst distanziert, obwohl er ein starker Teamplayer ist…",
            section: 6, sectionTitle: "Verhalten & Außenwirkung"
        ),
    ]
}
