import Foundation

@MainActor
final class SurveyService: ObservableObject {
    static let shared = SurveyService()

    @Published var selfResponses: [String: AnswerValue] = [:]
    @Published var isSubmitting = false

    var questions: [Question] { Question.surveyQuestions }

    private init() {
        loadSelfResponses()
    }

    func submitSelfAssessment(candidateId: String, responses: [String: AnswerValue]) async {
        isSubmitting = true
        defer { isSubmitting = false }
        selfResponses = responses

        // Persist locally
        if let data = try? JSONEncoder().encode(responses.mapValues { $0 }) {
            UserDefaults.standard.set(data, forKey: "pm_self_responses")
        }

        // TODO: for each (questionId, answer) in responses:
        // supabase.from("self_responses").insert([
        //   "candidate_id": candidateId, "question_id": questionId, "answer": answer.encoded
        // ])
        try? await Task.sleep(nanoseconds: 600_000_000)
    }

    private func loadSelfResponses() {
        // Try to restore from local storage
        // Full Supabase restore would be: supabase.from("self_responses").select().eq("candidate_id", userId)
    }
}
