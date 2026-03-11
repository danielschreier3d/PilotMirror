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
    let section: Int
    let sectionTitle: String
}

extension Question {
    static let surveyQuestions: [Question] = [
        // Section 1 — Trait selection
        Question(
            id: "q1",
            type: .traitSelection,
            text: "Which words describe this person? Select all that apply.",
            options: ["calm", "analytical", "confident", "team-oriented", "responsible",
                      "structured", "careful", "spontaneous", "dominant", "reserved",
                      "empathetic", "decisive"],
            scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            section: 1, sectionTitle: "Personality Traits"
        ),

        // Section 2 — Decision style (forced choice)
        Question(
            id: "q2",
            type: .forcedChoice,
            text: "This person decides more often:",
            options: ["Quickly and intuitively", "After careful analysis"],
            scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            section: 2, sectionTitle: "Decision Style"
        ),
        Question(
            id: "q3",
            type: .forcedChoice,
            text: "In groups this person tends to:",
            options: ["Lead the discussion", "Contribute ideas", "Observe first"],
            scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            section: 2, sectionTitle: "Decision Style"
        ),
        Question(
            id: "q4",
            type: .forcedChoice,
            text: "When something goes wrong this person reacts:",
            options: ["Calm and solution-focused", "Stressed but still functional", "Emotionally or frustrated"],
            scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            section: 2, sectionTitle: "Decision Style"
        ),

        // Section 3 — Rating scales
        Question(id: "q5", type: .ratingScale, text: "Teamwork", options: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, section: 3, sectionTitle: "Ratings"),
        Question(id: "q6", type: .ratingScale, text: "Stress Resistance", options: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, section: 3, sectionTitle: "Ratings"),
        Question(id: "q7", type: .ratingScale, text: "Responsibility", options: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, section: 3, sectionTitle: "Ratings"),
        Question(id: "q8", type: .ratingScale, text: "Communication", options: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, section: 3, sectionTitle: "Ratings"),
        Question(id: "q9", type: .ratingScale, text: "Reliability", options: nil, scaleMin: 1, scaleMax: 5, scaleLabel: nil, section: 3, sectionTitle: "Ratings"),

        // Section 4 — Open text
        Question(
            id: "q10",
            type: .openText,
            text: "What are this person's biggest strengths?",
            options: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            section: 4, sectionTitle: "Open Feedback"
        ),
        Question(
            id: "q11",
            type: .openText,
            text: "What could be a potential weakness of this person in a demanding selection process?",
            options: nil, scaleMin: nil, scaleMax: nil, scaleLabel: nil,
            section: 4, sectionTitle: "Open Feedback"
        ),
    ]
}
