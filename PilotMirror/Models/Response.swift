import Foundation

enum AnswerValue: Codable, Equatable {
    case text(String)
    case singleChoice(String)
    case multipleChoice([String])
    case rating(Int)

    enum CodingKeys: String, CodingKey { case type, value }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "text":     self = .text(try c.decode(String.self, forKey: .value))
        case "single":   self = .singleChoice(try c.decode(String.self, forKey: .value))
        case "multiple": self = .multipleChoice(try c.decode([String].self, forKey: .value))
        case "rating":   self = .rating(try c.decode(Int.self, forKey: .value))
        default:         self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let v):           try c.encode("text", forKey: .type);     try c.encode(v, forKey: .value)
        case .singleChoice(let v):   try c.encode("single", forKey: .type);   try c.encode(v, forKey: .value)
        case .multipleChoice(let v): try c.encode("multiple", forKey: .type); try c.encode(v, forKey: .value)
        case .rating(let v):         try c.encode("rating", forKey: .type);   try c.encode(v, forKey: .value)
        }
    }

    var displayText: String {
        switch self {
        case .text(let t):           return t
        case .singleChoice(let s):   return s
        case .multipleChoice(let m): return m.joined(separator: ", ")
        case .rating(let r):         return "\(r) / 5"
        }
    }
}

struct SurveyResponse: Identifiable, Codable {
    let id: String
    let respondentId: String
    let questionId: String
    let answer: AnswerValue
    let createdAt: Date
}
