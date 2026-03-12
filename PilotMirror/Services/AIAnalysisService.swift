import Foundation

@MainActor
final class AIAnalysisService: ObservableObject {
    static let shared = AIAnalysisService()

    @Published var isAnalyzing = false
    @Published var result: AnalysisResult?
    @Published var error: String?

    // Set your OpenAI API key here or load from environment
    private var apiKey: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    }
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    private init() {}

    func analyze(
        assessmentType: String,
        selfResponses: [String: AnswerValue],
        externalResponses: [[String: AnswerValue]]
    ) async {
        guard externalResponses.count >= 5 else {
            error = "At least 5 external responses are required."
            return
        }

        isAnalyzing = true
        defer { isAnalyzing = false }
        error = nil

        let prompt = buildPrompt(
            assessmentType: assessmentType,
            selfResponses: selfResponses,
            externalResponses: externalResponses
        )

        do {
            let json = try await callOpenAI(prompt: prompt)
            result = parseAnalysis(json)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Mock result (for demo without API key)

    func loadMockResult(assessmentType: String) {
        result = AnalysisResult(
            personalitySummary: "Du wirst von deinem Umfeld als ruhig, strukturiert und zuverlässig wahrgenommen. Du bringst eine analytische Denkweise mit und gehst Herausforderungen methodisch an. Andere schätzen deinen kühlen Kopf unter Druck — du bist das Gegenteil von impulsiv.",
            perceivedStrengths: [
                "Außergewöhnliche Stressresistenz — bleibst ruhig wenn andere hektisch werden",
                "Hohe Zuverlässigkeit — Zusagen werden konsequent eingehalten",
                "Analytisches Denken — durchdachte Entscheidungen statt Bauchgefühl",
                "Strukturiertes Vorgehen — planst voraus und behältst den Überblick",
            ],
            possibleWeaknesses: [
                "Wirkst in Gruppen zu passiv — andere interpretieren Ruhe als mangelndes Engagement",
                "Analysierst manchmal zu lange — unter Zeitdruck sind schnellere Entscheidungen gefragt",
            ],
            selfVsOthers: "Du schätzt dich bei Selbstvertrauen und Initiative deutlich höher ein als dein Umfeld dich wahrnimmt. Nach außen bist du eher der 'verlässliche Mitspieler' als der 'Treiber'. Das ist nicht negativ — aber im Assessment musst du aktiv dagegensteuern.",
            assessmentAdvice: "Gruppenübungen: Melde dich in den ersten 2 Minuten zu Wort — nicht weil du musst, sondern um die Wahrnehmung zu steuern. Interview: Bereite STAR-Beispiele vor, die zeigen dass du unter Druck entschieden hast. Entscheidungen: Übe 30-Sekunden-Entscheidungen — Geschwindigkeit zählt genauso wie Qualität.",
            generatedAt: Date(),
            comparisonAreas: [
                ComparisonArea(id: "teamwork",       name: "Teamwork",           selfRating: 4.0, othersAverage: 3.7),
                ComparisonArea(id: "stress",         name: "Stressresistenz",    selfRating: 3.5, othersAverage: 4.3),
                ComparisonArea(id: "responsibility", name: "Verantwortung",      selfRating: 5.0, othersAverage: 4.4),
                ComparisonArea(id: "communication",  name: "Kommunikation",      selfRating: 3.0, othersAverage: 3.6),
                ComparisonArea(id: "reliability",    name: "Zuverlässigkeit",    selfRating: 5.0, othersAverage: 4.7),
            ],
            traitStats: [
                TraitStat(id: "calm",          name: "ruhig",           selfSelected: true,  othersPercent: 0.86),
                TraitStat(id: "analytical",    name: "analytisch",      selfSelected: true,  othersPercent: 1.00),
                TraitStat(id: "confident",     name: "selbstsicher",    selfSelected: true,  othersPercent: 0.29),
                TraitStat(id: "team",          name: "teamorientiert",  selfSelected: false, othersPercent: 0.57),
                TraitStat(id: "responsible",   name: "verantwortungsb.",selfSelected: true,  othersPercent: 0.71),
                TraitStat(id: "structured",    name: "strukturiert",    selfSelected: true,  othersPercent: 0.86),
                TraitStat(id: "careful",       name: "bedachtsam",      selfSelected: false, othersPercent: 0.71),
                TraitStat(id: "spontaneous",   name: "spontan",         selfSelected: false, othersPercent: 0.14),
                TraitStat(id: "dominant",      name: "dominant",        selfSelected: false, othersPercent: 0.14),
                TraitStat(id: "reserved",      name: "zurückhaltend",   selfSelected: false, othersPercent: 0.57),
                TraitStat(id: "empathetic",    name: "empathisch",      selfSelected: false, othersPercent: 0.43),
                TraitStat(id: "decisive",      name: "entscheidungsst.",selfSelected: true,  othersPercent: 0.29),
            ],
            forcedChoiceStats: [
                ForcedChoiceStat(
                    id: "q2", question: "Entscheidet eher...",
                    selfChoice: "Nach sorgfältiger Analyse",
                    results: ["Schnell & intuitiv": 0.14, "Nach sorgfältiger Analyse": 0.86]
                ),
                ForcedChoiceStat(
                    id: "q3", question: "In Gruppen tendiert diese Person...",
                    selfChoice: "Ideen einzubringen",
                    results: ["Die Diskussion zu führen": 0.14, "Ideen einzubringen": 0.43, "Erst zu beobachten": 0.43]
                ),
                ForcedChoiceStat(
                    id: "q4", question: "Wenn etwas schiefläuft...",
                    selfChoice: "Ruhig & lösungsorientiert",
                    results: ["Ruhig & lösungsorientiert": 0.71, "Gestresst aber funktional": 0.29, "Emotional/frustriert": 0.00]
                ),
            ],
            openTextResponses: [
                "Extrem zuverlässig unter Druck. Hat immer Plan B in der Tasche.",
                "Bleibt immer ruhig — habe diese Person noch nie in Panik gesehen.",
                "Könnte in Gruppen mehr Initiative zeigen — wirkt manchmal zu zurückhaltend.",
                "Unglaublich strukturiert und vorbereitet. Setzt einen guten Maßstab.",
                "Analysiert manchmal zu viel — braucht schnellere Entscheidungen in zeitkritischen Situationen.",
                "Sehr verlässlich, aber tritt in Gruppen nicht genug in Erscheinung.",
                "Starker Teamplayer wenn man ihn kennt — braucht Zeit um aufzutauen.",
            ]
        )
    }

    // MARK: - Private

    private func buildPrompt(
        assessmentType: String,
        selfResponses: [String: AnswerValue],
        externalResponses: [[String: AnswerValue]]
    ) -> String {
        let questions = Question.surveyQuestions

        func format(_ responses: [String: AnswerValue]) -> String {
            questions.compactMap { q in
                guard let a = responses[q.id] else { return nil }
                let text = a.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
                // Skip clearly non-interpretable answers (< 3 chars, single letter, pure whitespace)
                if q.type == .openText && text.count < 3 { return nil }
                return "- \(q.text): \(text)"
            }.joined(separator: "\n")
        }

        return """
        You are an expert aviation psychologist conducting a structured 360-degree feedback analysis for a pilot candidate preparing for a \(assessmentType) selection process.

        ## EVALUATION FRAMEWORK
        You MUST assess the candidate on the following standardized aviation psychology dimensions, as used by selection boards (DLR, Lufthansa, Austrian Airlines, etc.):

        1. **Teamfähigkeit & Kooperation** — Ability to collaborate, follow and lead within a crew (CRM)
        2. **Kommunikation** — Clarity, assertiveness, active listening, openness
        3. **Führungsverhalten** — Takes initiative when appropriate; adapts leader/follower role situationally
        4. **Belastbarkeit & Stressresistenz** — Maintains performance and composure under pressure
        5. **Selbstwahrnehmung & Reflexionsfähigkeit** — Accuracy of self-perception; openness to feedback
        6. **Lernbereitschaft** — Receptiveness to new information, feedback, and personal development
        7. **Entscheidungsverhalten** — Speed and quality of decisions; handles uncertainty appropriately
        8. **Zuverlässigkeit & Verantwortungsbewusstsein** — Consistency, follow-through, accountability
        9. **Soziale Kompetenz** — Empathy, conflict resolution, interpersonal sensitivity

        ## ANSWER VALIDATION RULES
        - Ignore any free-text answer shorter than 3 meaningful characters (e.g., "x", "ok", "?") — treat as unanswered.
        - Spelling mistakes are acceptable and must NOT be used as a reason to discard an answer — interpret the intended meaning.
        - If an answer is ambiguous but plausible, interpret it charitably.

        ## CONSISTENCY REQUIREMENT
        Your analysis must be deterministic and framework-based. Do NOT produce vague or generic output. Every strength and weakness must map to at least one of the 9 dimensions above. Assessment advice must be specific to \(assessmentType).

        ## INPUT DATA

        SELF-PERCEPTION:
        \(format(selfResponses))

        EXTERNAL PERCEPTION (\(externalResponses.count) respondents):
        \(externalResponses.enumerated().map { i, r in "Respondent \(i+1):\n\(format(r))" }.joined(separator: "\n\n"))

        ## OUTPUT
        Respond in German. Respond in JSON with exactly these keys:
        - personalitySummary: string (3-4 sentences summarizing the candidate's personality profile based on external perception, referencing the assessment dimensions)
        - perceivedStrengths: string array (3-5 items, each prefixed with the relevant dimension, e.g. "Belastbarkeit: Bleibt auch unter Druck ruhig und lösungsorientiert")
        - possibleWeaknesses: string array (2-4 items, each prefixed with the relevant dimension, honest and direct — no softening language)
        - selfVsOthers: string (2-3 sentences on key discrepancies between self-rating and external perception, referencing specific dimensions)
        - assessmentAdvice: string (concrete, specific advice for \(assessmentType) — cover group exercise behavior, interview technique, and decision-making under time pressure)
        """
    }

    private func callOpenAI(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            // Return mock JSON when no key is set
            return mockJSON
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "You are an expert aviation psychologist. Respond only in valid JSON."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "response_format": ["type": "json_object"]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let content = choices?.first?["message"] as? [String: Any]
        guard let text = content?["content"] as? String else {
            throw URLError(.badServerResponse)
        }
        return text
    }

    private func parseAnalysis(_ json: String) -> AnalysisResult? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return AnalysisResult(
            personalitySummary: obj["personalitySummary"] as? String ?? "",
            perceivedStrengths: obj["perceivedStrengths"] as? [String] ?? [],
            possibleWeaknesses: obj["possibleWeaknesses"] as? [String] ?? [],
            selfVsOthers: obj["selfVsOthers"] as? String ?? "",
            assessmentAdvice: obj["assessmentAdvice"] as? String ?? "",
            generatedAt: Date(),
            comparisonAreas: [],
            traitStats: [],
            forcedChoiceStats: [],
            openTextResponses: []
        )
    }

    private let mockJSON = """
    {
      "personalitySummary": "This candidate is consistently perceived as calm, structured, and reliable. They demonstrate strong analytical thinking and a methodical approach to challenges.",
      "perceivedStrengths": ["Stress resistance", "Reliability", "Analytical decision-making", "Clear communication"],
      "possibleWeaknesses": ["May appear reserved in group settings", "Can over-analyze under time pressure"],
      "selfVsOthers": "You rate your confidence higher than others perceive it. Focus on speaking up earlier in group exercises.",
      "assessmentAdvice": "In group exercises, take initiative early. For interviews, prepare STAR-format examples of decisions under pressure."
    }
    """
}
