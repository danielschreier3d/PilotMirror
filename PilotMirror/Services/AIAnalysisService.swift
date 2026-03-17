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
    let respondentCountAtAnalysis: Int
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AIAnalysisService
// ─────────────────────────────────────────────────────────────────────────────
@MainActor
final class AIAnalysisService: ObservableObject {
    static let shared = AIAnalysisService()

    @Published var isAnalyzing  = false   // loading data
    @Published var isComputingAI = false  // AI call running in background
    @Published var result: AnalysisResult?
    @Published var error: String?
    @Published var openTextByQuestion: [String: [String]] = [:]
    @Published var cachedInterviewQuestions: [String] = []

    private static let interviewQuestionsKey = "pm_interview_questions_v1"

    // Raw data for relationship-based filtering
    @Published var respondentsWithRelationship: [Respondent] = []
    @Published var responsesByRespondentId: [String: [String: AnswerValue]] = [:]

    private let sb = SupabaseClient.shared
    private static let localCacheKey = "pm_analysis_result_v1"

    private init() {
        // Load cached result instantly from UserDefaults — no network call needed
        if let data = UserDefaults.standard.data(forKey: Self.localCacheKey),
           let cached = try? JSONDecoder().decode(AnalysisResult.self, from: data) {
            result = cached
        }
        // Load cached interview questions
        if let data = UserDefaults.standard.data(forKey: Self.interviewQuestionsKey),
           let questions = try? JSONDecoder().decode([String].self, from: data) {
            cachedInterviewQuestions = questions
        }
    }

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
        // Restore from local cache instantly (covers post-logout re-login case)
        if result == nil,
           let data = UserDefaults.standard.data(forKey: Self.localCacheKey),
           let cached = try? JSONDecoder().decode(AnalysisResult.self, from: data) {
            result = cached
        }

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
            let comparisonAreas: String?
            let traitStats: String?
            let forcedChoiceStats: String?
            let openTextResponses: [String]
            let respondentCountAtAnalysis: Int?
        }
        guard let record: AnalysisRead = try? await sb.selectFirst(
            from: "analysis_results",
            filters: ["session_id": "eq.\(sessionId)"]
        ) else { return }

        func decode<T: Decodable>(_ json: String?) -> [T] {
            guard let json, let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([T].self, from: data)) ?? []
        }

        // Load motivation data from respondents (not stored in analysis_results)
        let respondents = (try? await FeedbackService.shared.loadRespondentsWithRelationship()) ?? []
        let confidenceRatings = respondents.compactMap(\.confidenceRating)
        let confAvg: Double? = confidenceRatings.isEmpty ? nil
            : Double(confidenceRatings.reduce(0, +)) / Double(confidenceRatings.count)
        let wishes = respondents.compactMap(\.wishText).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        respondentsWithRelationship = respondents

        result = AnalysisResult(
            personalitySummary: record.personalitySummary,
            perceivedStrengths: record.strengths,
            possibleWeaknesses: record.weaknesses,
            selfVsOthers: record.selfVsOthers,
            assessmentAdvice: record.assessmentAdvice,
            generatedAt: Date(),
            comparisonAreas: decode(record.comparisonAreas),
            traitStats: decode(record.traitStats),
            forcedChoiceStats: decode(record.forcedChoiceStats),
            openTextResponses: record.openTextResponses,
            groupExerciseTips: record.groupExerciseTips ?? [],
            interviewTips: record.interviewTips ?? [],
            decisionMakingTips: record.decisionMakingTips ?? [],
            selfAwarenessTips: record.selfAwarenessTips ?? [],
            motivationConfidenceAvg: confAvg,
            motivationConfidenceCount: confidenceRatings.count,
            motivationWishes: wishes,
            respondentCount: record.respondentCountAtAnalysis ?? 0
        )
    }

    // MARK: – Full analysis with real Supabase data

    func analyzeFromBackend(
        assessmentType: String,
        userId: String,
        flightLicenses: [User.FlightLicense] = [],
        silent: Bool = false   // true = refresh stats only, no spinner, no AI re-run
    ) async {
        if !silent { isAnalyzing = true; error = nil }

        // Load self-responses
        await SurveyService.shared.loadSelfResponses(userId: userId)
        let selfResp = SurveyService.shared.selfResponses

        // Load respondent responses
        let externalResp: [[String: AnswerValue]]
        do {
            externalResp = try await FeedbackService.shared.loadRespondentResponses()
        } catch {
            if !silent { self.error = "Respondent load error: \(error.localizedDescription)" }
            if !silent { isAnalyzing = false }
            return
        }

        let link = FeedbackService.shared.feedbackLink
        guard externalResp.count >= 5 else {
            if !silent {
                error = "Zu wenig Antworten: \(externalResp.count) geladen. Link: \(link?.id.prefix(8) ?? "nil")"
                isAnalyzing = false
            }
            return
        }

        // Load respondents with relationship + motivation data
        let respondents = (try? await FeedbackService.shared.loadRespondentsWithRelationship()) ?? []
        respondentsWithRelationship = respondents
        responsesByRespondentId = (try? await FeedbackService.shared.loadRespondentResponsesWithId()) ?? [:]

        // Compute motivation data (NOT sent to AI)
        let confidenceRatings = respondents.compactMap(\.confidenceRating)
        let confAvg: Double? = confidenceRatings.isEmpty ? nil
            : Double(confidenceRatings.reduce(0, +)) / Double(confidenceRatings.count)
        let wishes = respondents.compactMap(\.wishText).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Publish computed stats immediately — navigation can happen now
        openTextByQuestion = collectOpenTextByQuestion(responses: externalResp)
        let freshStats = AnalysisResult(
            personalitySummary: "",
            perceivedStrengths: [],
            possibleWeaknesses: [],
            selfVsOthers: "",
            assessmentAdvice: "",
            generatedAt: Date(),
            comparisonAreas: computeComparisonAreas(self: selfResp, others: externalResp),
            traitStats: computeTraitStats(self: selfResp, others: externalResp),
            forcedChoiceStats: computeForcedChoiceStats(self: selfResp, others: externalResp),
            openTextResponses: collectOpenText(responses: externalResp),
            groupExerciseTips: [], interviewTips: [], decisionMakingTips: [], selfAwarenessTips: [],
            motivationConfidenceAvg: confAvg,
            motivationConfidenceCount: confidenceRatings.count,
            motivationWishes: wishes,
            respondentCount: externalResp.count
        )

        // Skip AI if respondent count hasn't changed since last analysis
        if let existing = result,
           existing.respondentCount == externalResp.count,
           !existing.personalitySummary.isEmpty {
            // Refresh stats (comparison areas etc.) but keep AI text
            result = AnalysisResult(
                personalitySummary: existing.personalitySummary,
                perceivedStrengths: existing.perceivedStrengths,
                possibleWeaknesses: existing.possibleWeaknesses,
                selfVsOthers: existing.selfVsOthers,
                assessmentAdvice: existing.assessmentAdvice,
                generatedAt: existing.generatedAt,
                comparisonAreas: freshStats.comparisonAreas,
                traitStats: freshStats.traitStats,
                forcedChoiceStats: freshStats.forcedChoiceStats,
                openTextResponses: freshStats.openTextResponses,
                groupExerciseTips: existing.groupExerciseTips,
                interviewTips: existing.interviewTips,
                decisionMakingTips: existing.decisionMakingTips,
                selfAwarenessTips: existing.selfAwarenessTips,
                motivationConfidenceAvg: confAvg,
                motivationConfidenceCount: confidenceRatings.count,
                motivationWishes: wishes,
                respondentCount: externalResp.count
            )
            if !silent { isAnalyzing = false }
            return
        }

        // In silent mode, never run the AI — only stats refresh was allowed
        if silent { return }

        result = freshStats
        isAnalyzing = false  // Release spinner — user navigates to results now

        // AI runs in background and updates result when ready
        let selfCapture     = selfResp
        let extCapture      = externalResp
        let licensesCapture = flightLicenses
        Task {
            isComputingAI = true
            defer { isComputingAI = false }
            let prompt = buildPrompt(
                assessmentType: assessmentType,
                selfResponses: selfCapture,
                externalResponses: extCapture,
                flightLicenses: licensesCapture)
            do {
                let json = try await callOpenAI(prompt: prompt)
                guard let full = parseAnalysis(json: json, selfResponses: selfCapture, externalResponses: extCapture) else {
                    self.error = "JSON parse failed. Response: \(json.prefix(200))"
                    return
                }
                result = full
                await storeResult(full)
                cacheInterviewQuestions(from: json)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: – Mock result for demo

    func loadMockResult(assessmentType: String) {
        result = AnalysisResult(
            personalitySummary: "Du wirst von deinem Umfeld als ruhig, strukturiert und zuverlässig wahrgenommen. Du bringst eine analytische Denkweise mit und gehst Herausforderungen methodisch an. Andere schätzen deinen kühlen Kopf unter Druck — du bist das Gegenteil von impulsiv.",
            perceivedStrengths: [
                "Belastbarkeit: Du hast eine außergewöhnliche Stressresistenz — du bleibst ruhig, wenn andere hektisch werden",
                "Zuverlässigkeit: Du bist sehr zuverlässig — deine Zusagen werden konsequent eingehalten",
                "Entscheidungsverhalten: Du denkst analytisch — deine Entscheidungen sind durchdacht statt impulsiv",
                "Teamfähigkeit: Du planst voraus und behältst dabei den Überblick",
            ],
            possibleWeaknesses: [
                "Führungsverhalten: Du wirkst in Gruppen zu passiv — andere interpretieren deine Ruhe als mangelndes Engagement",
                "Entscheidungsverhalten: Du analysierst manchmal zu lange — unter Zeitdruck sind schnellere Entscheidungen gefragt",
                "Kommunikation: Du meldest dich in Diskussionen zu selten aktiv zu Wort — deine Beiträge bleiben dadurch unsichtbar",
            ],
            selfVsOthers: "Du schätzt dich bei Selbstvertrauen und Initiative deutlich höher ein als dein Umfeld dich wahrnimmt. Nach außen wirkst du eher als 'verlässlicher Mitspieler' denn als 'Treiber'. Das ist nicht negativ — aber im Assessment solltest du aktiv dagegensteuern.",
            assessmentAdvice: "Melde dich in Gruppenübungen in den ersten 2 Minuten zu Wort. Bereite STAR-Beispiele vor, die zeigen, dass du unter Druck entschieden hast. Übe 30-Sekunden-Entscheidungen.",
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
            ],
            motivationConfidenceAvg: 4.2,
            motivationConfidenceCount: 5,
            motivationWishes: [
                "Ich wünsche dir viel Erfolg, du packst das!",
                "Bleib so wie du bist — du bist bereit!",
                "Wir glauben alle an dich. Du schaffst das!",
            ],
            respondentCount: 7
        )
    }

    // MARK: – Live interview hint (called on demand during interview simulation)

    func fetchInterviewHint(question: String, language: String) async throws -> String {
        var req = URLRequest(url: URL(string: SupabaseConfig.hintFunctionURL)!)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["question": question, "language": language])
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let err = json?["error"] as? String { throw NSError(domain: "HintFunction", code: -1, userInfo: [NSLocalizedDescriptionKey: err]) }
        return json?["hint"] as? String ?? ""
    }

    // MARK: – Private: Call Supabase Edge Function (Groq key stored server-side)

    private func callOpenAI(prompt: String) async throws -> String {
        guard let accessToken = sb.accessToken else { return mockJSON }

        var req = URLRequest(url: URL(string: SupabaseConfig.analyzeFunctionURL)!)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["prompt": prompt])

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let errMsg = json?["error"] as? String {
            throw NSError(domain: "EdgeFunction", code: -1,
                userInfo: [NSLocalizedDescriptionKey: errMsg])
        }
        guard let text = json?["result"] as? String else {
            throw NSError(domain: "EdgeFunction", code: -1,
                userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "no body"])
        }
        return text
    }

    // MARK: – Private: Prompt builder

    private func buildPrompt(
        assessmentType: String,
        selfResponses: [String: AnswerValue],
        externalResponses: [[String: AnswerValue]],
        flightLicenses: [User.FlightLicense] = []
    ) -> String {
        let questions = Question.surveyQuestions
        let n = externalResponses.count

        func format(_ responses: [String: AnswerValue]) -> String {
            questions.compactMap { q in
                guard let a = responses[q.id] else { return nil }
                let text = a.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
                if q.type == .openText && text.count < 3 { return nil }
                return "- \(q.text): \(text)"
            }.joined(separator: "\n")
        }

        // Compute rating comparison data (q5–q9) to give AI exact numbers
        let ratingDimensions: [(id: String, name: String)] = [
            ("q5", "Teamwork"), ("q6", "Stressresistenz"), ("q7", "Verantwortung"),
            ("q8", "Kommunikation"), ("q9", "Zuverlässigkeit"), ("q10_org", "Struktur/Organisation")
        ]
        let ratingsBlock: String = ratingDimensions.compactMap { dim in
            guard let selfVal: Double = {
                if case .rating(let r) = selfResponses[dim.id] { return Double(r) }
                return nil
            }() else { return nil }
            let otherVals: [Double] = externalResponses.compactMap {
                if case .rating(let r) = $0[dim.id] { return Double(r) }
                return nil
            }
            guard !otherVals.isEmpty else { return nil }
            let avg   = otherVals.reduce(0, +) / Double(otherVals.count)
            let delta = selfVal - avg
            let tag   = abs(delta) < 0.3 ? "≈ realistisch"
                      : delta > 0         ? "⬆ du schätzt dich höher"
                                          : "⬇ andere sehen dich stärker"
            return String(format: "  • %-18s du=%.1f  andere=Ø%.2f  delta=%+.2f  (%@)",
                          (dim.name + ":") as NSString, selfVal, avg, delta, tag)
        }.joined(separator: "\n")

        // Evidence thresholds (scale with respondent count)
        let highCount = max(2, Int(ceil(Double(n) * 0.40)))   // ≥40% = strong signal
        let modCount  = max(1, Int(ceil(Double(n) * 0.20)))   // ≥20% = notable

        // License context
        let relevantLicenses = flightLicenses.filter { $0 != .none }
        let licenseSection: String = {
            guard !relevantLicenses.isEmpty else { return "" }
            let labels = relevantLicenses.map(\.labelEN).joined(separator: ", ")
            return "\n\nCANDIDATE FLIGHT LICENSES: \(labels) — Tailor interviewTips and assessmentAdvice to reflect assessment questions typical for this license type."
        }()

        return """
        You are an expert aviation psychologist conducting a structured 360-degree feedback analysis \
        for a pilot candidate preparing for a \(assessmentType) selection process.

        ## EVALUATION DIMENSIONS
        Assess the candidate on these 10 aviation psychology dimensions:
        1. Teamfähigkeit & Kooperation — collaboration, CRM
        2. Kommunikation — clarity, assertiveness, active listening
        3. Führungsverhalten — initiative, leader/follower adaptability
        4. Belastbarkeit & Stressresistenz — composure under pressure
        5. Selbstwahrnehmung & Reflexionsfähigkeit — accuracy of self-perception
        6. Lernbereitschaft — openness to feedback and development
        7. Entscheidungsverhalten — speed and quality of decisions
        8. Zuverlässigkeit & Verantwortungsbewusstsein — consistency, accountability
        9. Soziale Kompetenz — empathy, conflict resolution
        10. Struktur & Organisation — planning, systematic approach, reliability under complexity

        ## STRUCTURED ANALYSIS PIPELINE — EXECUTE IN ORDER

        ### STEP 1 — Filter garbage answers
        Discard any free-text answer that:
        - Is shorter than 4 meaningful characters
        - Contains no real words (keyboard spam, "asdf", "123")
        - Is a refusal: "keine Ahnung", "weiß nicht", "n/a", "-", ".", "nichts"
        - Is pure filler: "gut", "okay", "ja", "nein" alone
        - Is off-topic or unrelated to the question
        Interpret minor spelling errors charitably. Keep all specific, observable statements.

        ### STEP 2 — Cluster external answers by theme
        For ALL \(n) respondents' free-text answers combined:
        - Group answers that describe the SAME core trait, even if worded differently.
          Example: "spricht zu wenig" + "hält sich zurück" + "meldet sich selten zu Wort"
          → ONE cluster: "passive Kommunikation in Gruppen" (evidence: 3 respondents)
        - Each cluster maps to exactly ONE of the 9 dimensions above.
        - Assign an evidence count to each cluster.
        Evidence thresholds for \(n) respondents:
          HIGH (≥\(highCount) respondents): strong, well-evidenced signal — always include
          MODERATE (\(modCount)–\(highCount - 1) respondents): notable — include if no overlap with a HIGH cluster
          WEAK (1 respondent): only use if the rating data below confirms it; otherwise skip

        ### STEP 3 — Consolidate and rank
        - Merge clusters that overlap into a SINGLE item.
        - Sort by evidence count (highest first).
        - Output 3 to 5 items. Prefer 3–4 unless there are clearly separate HIGH-evidence themes.
        - If only 1–2 distinct themes exist (e.g. everyone mentions the same weakness), output those
          2 items with detail, and add 1 item drawn from rating data or the self-assessment pattern.
        - NEVER split one theme into multiple bullet points just to reach 5.

        ### STEP 4 — Apply rating thresholds for selfVsOthers
        Use ONLY these exact computed values (do not invent numbers):
        \(ratingsBlock.isEmpty ? "  (no rating questions answered)" : ratingsBlock)

        Threshold rules:
          |delta| < 0.30  →  "realistisch" — do NOT flag as a discrepancy
          |delta| 0.30–0.69  →  "leichte Diskrepanz" — mention briefly
          |delta| ≥ 0.70  →  "deutliche Abweichung" — highlight clearly as assessment-relevant
        Delta > 0 means YOU rate yourself higher than others. Delta < 0 means others see you stronger.
        Name the 1–2 dimensions with the LARGEST |delta|.
        If ALL |delta| < 0.30: write that the candidate has a realistic overall self-image — this is a strength.

        ## INPUT DATA

        SELF-PERCEPTION:
        \(format(selfResponses))\(licenseSection)

        EXTERNAL PERCEPTION (\(n) respondents):
        \(externalResponses.enumerated().map { i, r in "Respondent \(i+1):\n\(format(r))" }.joined(separator: "\n\n"))

        ## LANGUAGE & TONE
        Respond in German. Address the candidate DIRECTLY using "du" (second person singular).
        NEVER write "der Kandidat" or "die Person" — always write "du", "dich", "dein", "deine".
        Every sentence must speak TO the candidate, not ABOUT them.

        ## OUTPUT
        Return ONLY valid JSON with exactly these keys (no markdown fences, no extra keys):
        - personalitySummary: string (3–4 sentences, "du"-form, references 2–3 dimensions)
        - strengths: string array (3–5 items from Step 3; format "Dimension: Beschreibung in du-Form"; highest evidence first)
        - weaknesses: string array (3–5 items from Step 3; format "Dimension: Beschreibung in du-Form"; highest evidence first; honest and direct)
        - selfVsOthers: string (2–3 sentences using Step 4 thresholds and exact delta values; cover realistic self-image case explicitly)
        - assessmentAdvice: string (concrete, personalized advice for \(assessmentType); "du"-form; tailor to license if provided)
        - groupExerciseTips: string array (3–5 personalized tips, "du"-form)
        - interviewTips: string array (3–5 personalized tips, "du"-form; reference flight experience if license provided)
        - decisionMakingTips: string array (3–5 personalized tips, "du"-form)
        - selfAwarenessTips: string array (3–5 tips based on Step 4 gaps; "du"-form; if all gaps < 0.30 explain what a realistic self-image means for the assessment)
        - interviewSimulationQuestions: string array (exactly 3 deeply personal interview questions in German, tailored to THIS candidate's specific weak points, self-perception gaps, and personality profile; mix of personal introspective and situational pressure questions; use "du"-form; they should probe the areas where the candidate is most likely to be challenged by a psychologist in a real interview — e.g. discrepancies between self-image and external perception, stress handling, decision-making under pressure, motivation authenticity)
        """
    }

    // MARK: – Private: Parse GPT response + compute stats from raw data

    private func parseAnalysis(
        json: String,
        selfResponses: [String: AnswerValue],
        externalResponses: [[String: AnswerValue]]
    ) -> AnalysisResult? {
        // Strip markdown code fences if present (e.g. ```json ... ```)
        var cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .components(separatedBy: "\n").dropFirst().joined(separator: "\n")
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = cleaned.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        func strings(_ key: String) -> [String] { obj[key] as? [String] ?? [] }

        // Preserve motivation data from already-loaded result (not from AI)
        let existing = result
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
            selfAwarenessTips:   strings("selfAwarenessTips"),
            motivationConfidenceAvg:   existing?.motivationConfidenceAvg,
            motivationConfidenceCount: existing?.motivationConfidenceCount ?? 0,
            motivationWishes:          existing?.motivationWishes ?? [],
            respondentCount:           existing?.respondentCount ?? externalResponses.count
        )
    }

    // MARK: – Stat computation from raw responses

    private func computeComparisonAreas(
        self selfR: [String: AnswerValue],
        others: [[String: AnswerValue]]
    ) -> [ComparisonArea] {
        let ratingQuestions: [(id: String, name: String)] = [
            ("q5", "Teamwork"), ("q6", "Stressresistenz"), ("q7", "Verantwortung"),
            ("q8", "Kommunikation"), ("q9", "Zuverlässigkeit"), ("q10_org", "Struktur/Organisation")
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

    /// Returns true if the text is a meaningful answer worth including
    private func isMeaningfulText(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard t.count >= 4 else { return false }
        // Reject if >60% of chars are not letters/spaces (likely keyboard spam)
        let letterCount = t.filter { $0.isLetter || $0.isWhitespace }.count
        guard Double(letterCount) / Double(t.count) > 0.6 else { return false }
        // Reject common non-answers
        let nonAnswers = ["keine ahnung", "weiß nicht", "weiss nicht", "kann ich nicht",
                          "nichts sagen", "no idea", "don't know", "n/a", "keine angabe",
                          "nichts", "nein", "ja", "gut", "okay", "ok", "---", "..."]
        return !nonAnswers.contains(where: { t.hasPrefix($0) || t == $0 })
    }

    private func collectOpenText(responses: [[String: AnswerValue]]) -> [String] {
        let openIds = ["q10","q11","q12","q13","q14","q15","q16","q17","q18"]
        return responses.flatMap { resp in
            openIds.compactMap { id -> String? in
                if case .text(let t) = resp[id] {
                    let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                    return isMeaningfulText(trimmed) ? trimmed : nil
                }
                return nil
            }
        }
    }

    private func collectOpenTextByQuestion(responses: [[String: AnswerValue]]) -> [String: [String]] {
        let openIds = ["q10","q11","q12","q13","q14","q15","q16","q17","q18"]
        var grouped: [String: [String]] = [:]
        for resp in responses {
            for id in openIds {
                if case .text(let t) = resp[id] {
                    let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                    if isMeaningfulText(trimmed) { grouped[id, default: []].append(trimmed) }
                }
            }
        }
        return grouped
    }

    // MARK: – Relationship-based filter methods (live recomputation, no re-fetch)

    func filteredTraitStats(for relationship: Respondent.RelationshipType?) -> [TraitStat] {
        let filteredResponses = filteredExternalResponses(for: relationship)
        let selfResp = SurveyService.shared.selfResponses
        return computeTraitStats(self: selfResp, others: filteredResponses)
    }

    func filteredComparisonAreas(for relationship: Respondent.RelationshipType?) -> [ComparisonArea] {
        let filteredResponses = filteredExternalResponses(for: relationship)
        let selfResp = SurveyService.shared.selfResponses
        return computeComparisonAreas(self: selfResp, others: filteredResponses)
    }

    func filteredForcedChoiceStats(for relationship: Respondent.RelationshipType?) -> [ForcedChoiceStat] {
        let filteredResponses = filteredExternalResponses(for: relationship)
        let selfResp = SurveyService.shared.selfResponses
        return computeForcedChoiceStats(self: selfResp, others: filteredResponses)
    }

    func filteredOpenText(for relationship: Respondent.RelationshipType?) -> [String: [String]] {
        let filteredResponses = filteredExternalResponses(for: relationship)
        return collectOpenTextByQuestion(responses: filteredResponses)
    }

    private func filteredExternalResponses(for relationship: Respondent.RelationshipType?) -> [[String: AnswerValue]] {
        guard let rel = relationship else {
            // No filter — return all
            return responsesByRespondentId.values.map { $0 }
        }
        return respondentsWithRelationship
            .filter { $0.relationship == rel }
            .compactMap { responsesByRespondentId[$0.id] }
    }

    // MARK: – Cache AI-generated interview questions

    private func cacheInterviewQuestions(from json: String) {
        var cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
            if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = cleaned.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let questions = obj["interviewSimulationQuestions"] as? [String],
              !questions.isEmpty
        else { return }

        cachedInterviewQuestions = questions
        if let encoded = try? JSONEncoder().encode(questions) {
            UserDefaults.standard.set(encoded, forKey: Self.interviewQuestionsKey)
        }
    }

    // MARK: – Store result to Supabase

    private func storeResult(_ r: AnalysisResult) async {
        // Save to UserDefaults for instant load on next app launch
        if let data = try? JSONEncoder().encode(r) {
            UserDefaults.standard.set(data, forKey: Self.localCacheKey)
        }

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
            forcedChoiceStats: fcJSON, openTextResponses: r.openTextResponses,
            respondentCountAtAnalysis: r.respondentCount
        )
        try? await sb.upsert(into: "analysis_results", value: record, onConflict: "session_id")
    }

    // MARK: – Mock JSON fallback (no API key)

    private let mockJSON = """
    {
      "personalitySummary": "Du wirst von deinem Umfeld als ruhig, strukturiert und zuverlässig wahrgenommen.",
      "strengths": ["Belastbarkeit: Du bleibst ruhig unter Druck", "Zuverlässigkeit: Du hältst Zusagen konsequent ein"],
      "weaknesses": ["Führungsverhalten: Du wirkst in Gruppen zu passiv"],
      "selfVsOthers": "Du schätzt dein Selbstvertrauen höher ein als andere dich wahrnehmen.",
      "assessmentAdvice": "Melde dich in Gruppenübungen früh zu Wort. Nutze das STAR-Format im Interview.",
      "groupExerciseTips": ["Melde dich in den ersten 2 Minuten zu Wort"],
      "interviewTips": ["Bereite 5 STAR-Beispiele vor"],
      "decisionMakingTips": ["Übe 30-Sekunden-Entscheidungen"],
      "selfAwarenessTips": ["Deine größte Lücke: Selbstvertrauen vs. Außenwahrnehmung"]
    }
    """
}
