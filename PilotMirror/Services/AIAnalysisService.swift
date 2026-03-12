import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Backend DTO for analysis_results table
// ─────────────────────────────────────────────────────────────────────────────
private struct AnalysisResultInsert: Encodable {
    let id: String
    let sessionId: String
    let personalitySummary: String
    let strengths: [String]
    let weaknesses: [String]
    let selfVsOthers: String
    let assessmentAdvice: String
    let groupExerciseTips: [String]
    let interviewTips: [String]
    let decisionMakingTips: [String]
    let selfAwarenessTips: [String]
    let comparisonAreas: String   // JSON-encoded
    let traitStats: String        // JSON-encoded
    let forcedChoiceStats: String // JSON-encoded
    let openTextResponses: [String]
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AIAnalysisService
// ─────────────────────────────────────────────────────────────────────────────
@MainActor
final class AIAnalysisService: ObservableObject {
    static let shared = AIAnalysisService()

    @Published var isAnalyzing = false
    @Published var result: AnalysisResult?
    @Published var error: String?

    private let sb       = SupabaseClient.shared
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    private init() {}

    // MARK: – Main entry point

    func analyze(
        assessmentType: String,
        selfResponses: [String: AnswerValue],
        externalResponses: [[String: AnswerValue]]
    ) async {
        guard externalResponses.count >= 5 else {
            error = "At least 5 external responses are required."
            return
        }
        isAnalyzing = true; defer { isAnalyzing = false }
        error = nil

        let prompt = buildPrompt(
            assessmentType: assessmentType,
            selfResponses: selfResponses,
            externalResponses: externalResponses)

        do {
            let json = try await callOpenAI(prompt: prompt)
            guard let analysisResult = parseAnalysis(
                json: json,
                selfResponses: selfResponses,
                externalResponses: externalResponses) else {
                self.error = "Failed to parse AI response."
                return
            }
            result = analysisResult
            await storeResult(analysisResult)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: – Load existing result from Supabase

    func loadExistingResult() async {
        guard let sessionId = UserDefaults.standard.string(forKey: "pm_session_id") else { return }
        struct AnalysisRead: Decodable {
            let personalitySummary: String
            let strengths: [String]
            let weaknesses: [String]
            let selfVsOthers: String
            let assessmentAdvice: String
            let groupExerciseTips: [String]?
            let interviewTips: [String]?
            let decisionMakingTips: [String]?
            let selfAwarenessTips: [String]?
            let openTextResponses: [String]
        }
        if let record: AnalysisRead = try? await sb.selectFirst(
            from: "analysis_results",
            filters: ["session_id": "eq.\(sessionId)"]
        ) {
            result = AnalysisResult(
                personalitySummary: record.personalitySummary,
                perceivedStrengths: record.strengths,
                possibleWeaknesses: record.weaknesses,
                selfVsOthers: record.selfVsOthers,
                assessmentAdvice: record.assessmentAdvice,
                generatedAt: Date(),
                comparisonAreas: [],
                traitStats: [],
                forcedChoiceStats: [],
                openTextResponses: record.openTextResponses,
                groupExerciseTips: record.groupExerciseTips ?? [],
                interviewTips: record.interviewTips ?? [],
                decisionMakingTips: record.decisionMakingTips ?? [],
                selfAwarenessTips: record.selfAwarenessTips ?? []
            )
        }
    }

    // MARK: – Full analysis with real Supabase data

    func analyzeFromBackend(
        assessmentType: String,
        userId: String
    ) async {
        isAnalyzing = true; defer { isAnalyzing = false }
        error = nil

        // Load self-responses
        await SurveyService.shared.loadSelfResponses(userId: userId)
        let selfResp = SurveyService.shared.selfResponses

        // Load respondent responses
        let externalResp = (try? await FeedbackService.shared.loadRespondentResponses()) ?? []

        guard externalResp.count >= 5 else {
            error = "At least 5 external responses are required."
            return
        }
        await analyze(assessmentType: assessmentType,
                      selfResponses: selfResp,
                      externalResponses: externalResp)
    }

    // MARK: – Mock result for demo

    func loadMockResult(assessmentType: String) {
        result = AnalysisResult(
            personalitySummary: "Du wirst von deinem Umfeld als ruhig, strukturiert und zuverlässig wahrgenommen. Du bringst eine analytische Denkweise mit und gehst Herausforderungen methodisch an. Andere schätzen deinen kühlen Kopf unter Druck — du bist das Gegenteil von impulsiv.",
            perceivedStrengths: [
                "Belastbarkeit: Außergewöhnliche Stressresistenz — bleibst ruhig wenn andere hektisch werden",
                "Zuverlässigkeit: Hohe Zuverlässigkeit — Zusagen werden konsequent eingehalten",
                "Entscheidungsverhalten: Analytisches Denken — durchdachte Entscheidungen statt Bauchgefühl",
                "Teamfähigkeit: Strukturiertes Vorgehen — planst voraus und behältst den Überblick",
            ],
            possibleWeaknesses: [
                "Führungsverhalten: Wirkst in Gruppen zu passiv — andere interpretieren Ruhe als mangelndes Engagement",
                "Entscheidungsverhalten: Analysierst manchmal zu lange — unter Zeitdruck sind schnellere Entscheidungen gefragt",
            ],
            selfVsOthers: "Du schätzt dich bei Selbstvertrauen und Initiative deutlich höher ein als dein Umfeld dich wahrnimmt. Nach außen bist du eher der 'verlässliche Mitspieler' als der 'Treiber'. Das ist nicht negativ — aber im Assessment musst du aktiv dagegensteuern.",
            assessmentAdvice: "Gruppenübungen: Melde dich in den ersten 2 Minuten zu Wort. Interview: Bereite STAR-Beispiele vor, die zeigen dass du unter Druck entschieden hast. Entscheidungen: Übe 30-Sekunden-Entscheidungen.",
            generatedAt: Date(),
            comparisonAreas: [
                ComparisonArea(id: "teamwork",       name: "Teamwork",        selfRating: 4.0, othersAverage: 3.7),
                ComparisonArea(id: "stress",         name: "Stressresistenz", selfRating: 3.5, othersAverage: 4.3),
                ComparisonArea(id: "responsibility", name: "Verantwortung",   selfRating: 5.0, othersAverage: 4.4),
                ComparisonArea(id: "communication",  name: "Kommunikation",   selfRating: 3.0, othersAverage: 3.6),
                ComparisonArea(id: "reliability",    name: "Zuverlässigkeit", selfRating: 5.0, othersAverage: 4.7),
            ],
            traitStats: [
                TraitStat(id: "calm",       name: "ruhig",          selfSelected: true,  othersPercent: 0.86),
                TraitStat(id: "analytical", name: "analytisch",     selfSelected: true,  othersPercent: 1.00),
                TraitStat(id: "confident",  name: "selbstsicher",   selfSelected: true,  othersPercent: 0.29),
                TraitStat(id: "team",       name: "teamorientiert", selfSelected: false, othersPercent: 0.57),
                TraitStat(id: "structured", name: "strukturiert",   selfSelected: true,  othersPercent: 0.86),
                TraitStat(id: "reserved",   name: "zurückhaltend",  selfSelected: false, othersPercent: 0.57),
                TraitStat(id: "decisive",   name: "entschlossen",   selfSelected: true,  othersPercent: 0.29),
            ],
            forcedChoiceStats: [
                ForcedChoiceStat(id: "q2", question: "Entscheidet eher...",
                    selfChoice: "Nach sorgfältiger Analyse",
                    results: ["Schnell & intuitiv": 0.14, "Nach sorgfältiger Analyse": 0.86]),
                ForcedChoiceStat(id: "q3", question: "In Gruppen tendiert diese Person...",
                    selfChoice: "Ideen einzubringen",
                    results: ["Die Diskussion zu führen": 0.14, "Ideen einzubringen": 0.43, "Erst zu beobachten": 0.43]),
            ],
            openTextResponses: [
                "Extrem zuverlässig unter Druck. Hat immer Plan B in der Tasche.",
                "Bleibt immer ruhig — habe diese Person noch nie in Panik gesehen.",
                "Könnte in Gruppen mehr Initiative zeigen — wirkt manchmal zu zurückhaltend.",
                "Analysiert manchmal zu viel — braucht schnellere Entscheidungen in zeitkritischen Situationen.",
            ],
            groupExerciseTips: [
                "Melde dich in den ersten 2 Minuten zu Wort — deine Zurückhaltung wird als Desinteresse gelesen",
                "Biete an, die Gruppenposition zusammenzufassen — zeigt Führungsbereitschaft",
                "Achte auf deine Redezeit — du neigst dazu, zu lange zu analysieren bevor du sprichst",
            ],
            interviewTips: [
                "Bereite 5 STAR-Beispiele vor, die Entscheidungen unter Zeitdruck zeigen",
                "Betone deine Stärke in der Ruhe — aber erkläre, dass du auch schnell handeln kannst",
                "Zeige Selbstreflexion: benenne deine Tendenz zur Überanalyse als echte Schwäche mit Lösungsgeschichte",
            ],
            decisionMakingTips: [
                "Übe 30-Sekunden-Entscheidungen in Rollenspielen",
                "Kommuniziere deine Absicht laut bevor du handelst",
                "Wenn unsicher: Sage was du denkst — Assessoren schätzen Transparenz über Schweigen",
            ],
            selfAwarenessTips: [
                "Dein größte Diskrepanz: Du siehst dich als selbstsicher — andere sehen dich als zurückhaltend",
                "Nutze deinen Report als Spiegel: Übe das Gegenteil deiner natürlichen Tendenz",
                "Sei konsistent zwischen dem was du im Interview sagst und dem was Assessoren beobachten",
            ]
        )
    }

    // MARK: – Private: OpenAI call

    private func callOpenAI(prompt: String) async throws -> String {
        let apiKey = SupabaseConfig.openAIKey
        guard !apiKey.hasPrefix("sk-YOUR") else { return mockJSON }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "You are an expert aviation psychologist. Respond only in valid JSON."],
                ["role": "user",   "content": prompt]
            ],
            "temperature": 0.7,
            "response_format": ["type": "json_object"]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json      = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = (json?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any],
              let content = text["content"] as? String else {
            throw URLError(.badServerResponse)
        }
        return content
    }

    // MARK: – Private: Prompt builder

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
                if q.type == .openText && text.count < 3 { return nil }
                return "- \(q.text): \(text)"
            }.joined(separator: "\n")
        }

        return """
        You are an expert aviation psychologist conducting a structured 360-degree feedback analysis \
        for a pilot candidate preparing for a \(assessmentType) selection process.

        ## EVALUATION FRAMEWORK
        Assess the candidate on these aviation psychology dimensions:
        1. Teamfähigkeit & Kooperation — collaboration, CRM
        2. Kommunikation — clarity, assertiveness, active listening
        3. Führungsverhalten — initiative, leader/follower adaptability
        4. Belastbarkeit & Stressresistenz — composure under pressure
        5. Selbstwahrnehmung & Reflexionsfähigkeit — accuracy of self-perception
        6. Lernbereitschaft — openness to feedback and development
        7. Entscheidungsverhalten — speed and quality of decisions
        8. Zuverlässigkeit & Verantwortungsbewusstsein — consistency, accountability
        9. Soziale Kompetenz — empathy, conflict resolution

        ## VALIDATION RULES
        - Ignore free-text answers shorter than 3 meaningful characters.
        - Interpret spelling mistakes charitably.
        - Every strength/weakness must map to at least one dimension above.

        ## INPUT DATA

        SELF-PERCEPTION:
        \(format(selfResponses))

        EXTERNAL PERCEPTION (\(externalResponses.count) respondents):
        \(externalResponses.enumerated().map { i, r in "Respondent \(i+1):\n\(format(r))" }.joined(separator: "\n\n"))

        ## OUTPUT
        Respond in German. Return JSON with exactly these keys:
        - personalitySummary: string (3-4 sentences, references dimensions)
        - strengths: string array (3-5 items, prefixed with dimension name)
        - weaknesses: string array (2-4 items, prefixed with dimension name, honest and direct)
        - selfVsOthers: string (2-3 sentences on key discrepancies)
        - assessmentAdvice: string (concrete advice specific to \(assessmentType))
        - groupExerciseTips: string array (3-5 specific, personalized tips for group exercise)
        - interviewTips: string array (3-5 specific, personalized tips for interview)
        - decisionMakingTips: string array (3-5 specific tips for decision-making exercises)
        - selfAwarenessTips: string array (3-5 tips based on the self vs others gap)
        """
    }

    // MARK: – Private: Parse GPT response + compute stats from raw data

    private func parseAnalysis(
        json: String,
        selfResponses: [String: AnswerValue],
        externalResponses: [[String: AnswerValue]]
    ) -> AnalysisResult? {
        guard let data = json.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        func strings(_ key: String) -> [String] { obj[key] as? [String] ?? [] }

        return AnalysisResult(
            personalitySummary: obj["personalitySummary"] as? String ?? "",
            perceivedStrengths: strings("strengths"),
            possibleWeaknesses: strings("weaknesses"),
            selfVsOthers:       obj["selfVsOthers"]      as? String ?? "",
            assessmentAdvice:   obj["assessmentAdvice"]  as? String ?? "",
            generatedAt:        Date(),
            comparisonAreas:    computeComparisonAreas(self: selfResponses, others: externalResponses),
            traitStats:         computeTraitStats(self: selfResponses, others: externalResponses),
            forcedChoiceStats:  computeForcedChoiceStats(self: selfResponses, others: externalResponses),
            openTextResponses:  collectOpenText(responses: externalResponses),
            groupExerciseTips:   strings("groupExerciseTips"),
            interviewTips:       strings("interviewTips"),
            decisionMakingTips:  strings("decisionMakingTips"),
            selfAwarenessTips:   strings("selfAwarenessTips")
        )
    }

    // MARK: – Stat computation from raw responses

    private func computeComparisonAreas(
        self selfR: [String: AnswerValue],
        others: [[String: AnswerValue]]
    ) -> [ComparisonArea] {
        let ratingQuestions: [(id: String, name: String)] = [
            ("q5", "Teamwork"), ("q6", "Stressresistenz"), ("q7", "Verantwortung"),
            ("q8", "Kommunikation"), ("q9", "Zuverlässigkeit")
        ]
        return ratingQuestions.compactMap { q in
            let selfVal: Double = {
                if case .rating(let r) = selfR[q.id] { return Double(r) }
                return 0
            }()
            let otherVals: [Double] = others.compactMap {
                if case .rating(let r) = $0[q.id] { return Double(r) }
                return nil
            }
            guard !otherVals.isEmpty else { return nil }
            let avg = otherVals.reduce(0, +) / Double(otherVals.count)
            return ComparisonArea(id: q.id, name: q.name,
                                  selfRating: selfVal, othersAverage: avg)
        }
    }

    private func computeTraitStats(
        self selfR: [String: AnswerValue],
        others: [[String: AnswerValue]]
    ) -> [TraitStat] {
        let canonical = Question.surveyQuestions.first(where: { $0.id == "q1" })?.options ?? []
        let selfSelected: Set<String> = {
            if case .multipleChoice(let m) = selfR["q1"] { return Set(m) }
            return []
        }()
        return canonical.enumerated().map { i, trait in
            let count = others.filter {
                if case .multipleChoice(let m) = $0["q1"] { return m.contains(trait) }
                return false
            }.count
            return TraitStat(
                id: "trait_\(i)",
                name: trait,
                selfSelected: selfSelected.contains(trait),
                othersPercent: others.isEmpty ? 0 : Double(count) / Double(others.count)
            )
        }
    }

    private func computeForcedChoiceStats(
        self selfR: [String: AnswerValue],
        others: [[String: AnswerValue]]
    ) -> [ForcedChoiceStat] {
        let fcQuestions: [(id: String, text: String)] = [
            ("q2", "Entscheidet eher..."),
            ("q3", "In Gruppen tendiert diese Person..."),
            ("q4", "Wenn etwas schiefläuft...")
        ]
        return fcQuestions.compactMap { q in
            let options = Question.surveyQuestions.first(where: { $0.id == q.id })?.options ?? []
            let selfChoice: String = {
                if case .singleChoice(let s) = selfR[q.id] { return s }
                return ""
            }()
            var counts: [String: Int] = Dictionary(uniqueKeysWithValues: options.map { ($0, 0) })
            for resp in others {
                if case .singleChoice(let s) = resp[q.id] { counts[s, default: 0] += 1 }
            }
            let total = Double(others.count)
            let results = counts.mapValues { total > 0 ? Double($0) / total : 0.0 }
            return ForcedChoiceStat(id: q.id, question: q.text, selfChoice: selfChoice, results: results)
        }
    }

    private func collectOpenText(responses: [[String: AnswerValue]]) -> [String] {
        let openIds = ["q10","q11","q12","q13","q14","q15","q16","q17","q18"]
        return responses.flatMap { resp in
            openIds.compactMap { id -> String? in
                if case .text(let t) = resp[id] {
                    let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.count >= 3 ? trimmed : nil
                }
                return nil
            }
        }
    }

    // MARK: – Store result to Supabase

    private func storeResult(_ r: AnalysisResult) async {
        guard let sessionId = UserDefaults.standard.string(forKey: "pm_session_id") else { return }
        let areasJSON  = (try? String(data: JSONEncoder().encode(r.comparisonAreas),  encoding: .utf8)) ?? "[]"
        let traitsJSON = (try? String(data: JSONEncoder().encode(r.traitStats),       encoding: .utf8)) ?? "[]"
        let fcJSON     = (try? String(data: JSONEncoder().encode(r.forcedChoiceStats),encoding: .utf8)) ?? "[]"

        let record = AnalysisResultInsert(
            id: UUID().uuidString, sessionId: sessionId,
            personalitySummary: r.personalitySummary,
            strengths: r.perceivedStrengths, weaknesses: r.possibleWeaknesses,
            selfVsOthers: r.selfVsOthers, assessmentAdvice: r.assessmentAdvice,
            groupExerciseTips: r.groupExerciseTips, interviewTips: r.interviewTips,
            decisionMakingTips: r.decisionMakingTips, selfAwarenessTips: r.selfAwarenessTips,
            comparisonAreas: areasJSON, traitStats: traitsJSON,
            forcedChoiceStats: fcJSON, openTextResponses: r.openTextResponses
        )
        try? await sb.upsert(into: "analysis_results", value: record, onConflict: "session_id")
    }

    // MARK: – Mock JSON fallback (no API key)

    private let mockJSON = """
    {
      "personalitySummary": "Der Kandidat wird als ruhig, strukturiert und zuverlässig wahrgenommen.",
      "strengths": ["Belastbarkeit: Bleibt ruhig unter Druck", "Zuverlässigkeit: Hält Zusagen konsequent ein"],
      "weaknesses": ["Führungsverhalten: Wirkt in Gruppen zu passiv"],
      "selfVsOthers": "Kandidat schätzt Selbstvertrauen höher ein als andere ihn wahrnehmen.",
      "assessmentAdvice": "In Gruppenübungen früh zu Wort melden. STAR-Format im Interview.",
      "groupExerciseTips": ["Melde dich in den ersten 2 Minuten zu Wort"],
      "interviewTips": ["Bereite 5 STAR-Beispiele vor"],
      "decisionMakingTips": ["Übe 30-Sekunden-Entscheidungen"],
      "selfAwarenessTips": ["Größte Lücke: Selbstvertrauen vs. Außenwahrnehmung"]
    }
    """
}
