import SwiftUI

enum SurveyMode {
    case respondent(token: String)
    case selfAssessment
}

struct FeedbackSurveyView: View {
    let mode: SurveyMode
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var lang: LanguageService
    @Environment(\.dismiss) var dismiss

    @State private var currentIndex = 0
    @State private var responses: [String: AnswerValue] = [:]
    @State private var respondentName = ""
    @State private var respondentRelationship = Respondent.RelationshipType.friend
    @State private var showIntro = true
    @State private var isSubmitting = false
    @State private var isComplete = false

    // Motivation (respondent-only, Q19/Q20)
    @State private var confidenceRating: Int? = nil
    @State private var wishText: String = ""

    // Candidate name for respondent personalization
    @State private var candidateName: String? = nil

    // Full question list for this session
    @State private var allQuestions: [Question] = []

    // Whether we're showing the motivation epilogue (after last standard question, respondent only)
    @State private var showMotivation = false

    var currentQuestion: Question { allQuestions[currentIndex] }
    var progress: Double {
        guard !allQuestions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(allQuestions.count)
    }

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()

            if isComplete {
                completionScreen
            } else if showIntro {
                introScreen
            } else if showMotivation {
                motivationScreen
            } else {
                questionScreen
            }
        }
        .task {
            await setup()
        }
    }

    // MARK: - Setup

    private func setup() async {
        // Build question list
        switch mode {
        case .selfAssessment:
            allQuestions = Question.surveyQuestions

        case .respondent(let token):
            allQuestions = Question.surveyQuestions
            // Fetch candidate name for personalization
            if let name = try? await fetchCandidateName(token: token) {
                candidateName = name
            }
        }
    }

    private func fetchCandidateName(token: String) async throws -> String? {
        struct CandidateInfo: Decodable { let candidateName: String? }
        let rows: [CandidateInfo] = try await SupabaseClient.shared.rpc(
            function: "get_candidate_info_by_token",
            params: ["p_token": token],
            anonOnly: true)
        return rows.first?.candidateName
    }

    // MARK: - Intro

    private var introScreen: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: mode.isRespondent ? "lock.shield.fill" : "person.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color(hex: "4A9EF8"))

                Text(mode.isRespondent
                     ? lang.t("Dein Feedback ist anonym", "Your feedback is anonymous")
                     : lang.t("Sei ehrlich zu dir selbst", "Rate yourself honestly"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appPrimary)
                    .multilineTextAlignment(.center)

                Text(mode.isRespondent
                     ? lang.t(
                        "Dein Name wird dem Kandidaten nie angezeigt. Deine Antworten sind vertraulich und dienen ausschließlich der anonymen Auswertung.",
                        "Your name will never be shown to the candidate. Your answers are confidential and used only to generate an anonymous report.")
                     : lang.t(
                        "Beantworte die Fragen zu deiner eigenen Selbstwahrnehmung. Sei so ehrlich wie möglich — dieser Vergleich ist der Kern deines Reports.",
                        "Answer the questions about your own self-perception. Be as honest as possible — this comparison is the core of your report."))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal)

                Text(lang.t("Dauert weniger als 5 Minuten", "Takes less than 5 minutes"))
                    .font(.caption)
                    .foregroundStyle(Color(hex: "34C759"))
            }

            if mode.isRespondent {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color(hex: "4A9EF8"))
                        TextField(lang.t("Dein Vorname", "Your first name"), text: $respondentName)
                            .foregroundStyle(Color.appPrimary)
                            .autocorrectionDisabled()
                    }
                    .padding()
                    .background(Color.appInputBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Picker("Relationship", selection: $respondentRelationship) {
                        ForEach(Respondent.RelationshipType.allCases, id: \.self) { r in
                            Text(lang.isGerman ? r.labelDE : r.labelEN).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color(hex: "4A9EF8"))
                    .padding()
                    .background(Color.appInputBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }

            Button {
                withAnimation { showIntro = false }
            } label: {
                Text(lang.t("Umfrage starten", "Start Survey"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "4A9EF8"))
                    .foregroundStyle(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .disabled(mode.isRespondent && respondentName.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
        }
    }

    // MARK: - Question

    private var questionScreen: some View {
        VStack(spacing: 0) {
            // Progress
            VStack(spacing: 8) {
                HStack {
                    Text(lang.t("Frage \(currentIndex + 1) von \(allQuestions.count)",
                                "Question \(currentIndex + 1) of \(allQuestions.count)"))
                        .font(.caption)
                        .foregroundStyle(Color.appSecondary)
                    Spacer()
                    Text(currentQuestion.displaySectionTitle(isGerman: lang.isGerman))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "4A9EF8"))
                }
                ProgressView(value: progress)
                    .tint(Color(hex: "4A9EF8"))
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())
                    .animation(.spring(response: 0.4), value: progress)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView {
                QuestionCard(
                    question: currentQuestion,
                    answer: responses[currentQuestion.id],
                    mode: mode,
                    candidateName: candidateName,
                    onAnswer: { value in responses[currentQuestion.id] = value }
                )
                .padding()
                .id(currentIndex)
            }

            HStack(spacing: 12) {
                if currentIndex > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { currentIndex -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 52, height: 52)
                            .background(Color.appInputBG)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(Color.appPrimary)
                    }
                }

                Button {
                    advanceQuestion()
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            let isLast = currentIndex == allQuestions.count - 1
                            Text(isLast
                                 ? (mode.isRespondent
                                    ? lang.t("Weiter", "Next")   // motivation screen follows
                                    : lang.t("Absenden", "Submit"))
                                 : lang.t("Weiter", "Next"))
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canAdvance ? Color(hex: "4A9EF8") : Color.appBorder)
                    .foregroundStyle(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .animation(.easeInOut(duration: 0.2), value: canAdvance)
                }
                .disabled(!canAdvance || isSubmitting)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private var canAdvance: Bool {
        let q = currentQuestion
        if q.type == .openText { return true }
        return responses[q.id] != nil
    }

    private func advanceQuestion() {
        let isLast = currentIndex == allQuestions.count - 1
        if !isLast {
            withAnimation(.easeInOut(duration: 0.2)) { currentIndex += 1 }
        } else if mode.isRespondent {
            withAnimation { showMotivation = true }
        } else {
            submitSurvey()
        }
    }

    // MARK: - Motivation screen (respondent only, after last question)

    private var motivationScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                VStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color(hex: "FF6B6B"))

                    Text(lang.t("Fast geschafft!", "Almost done!"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appPrimary)

                    let name = candidateName ?? lang.t("der Kandidat", "the candidate")
                    Text(lang.t(
                        "Zwei optionale Fragen — deine Antworten sieht nur \(name) selbst als Motivation.",
                        "Two optional questions — only \(name) will see your answers as motivation."))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Confidence rating
                VStack(alignment: .leading, spacing: 12) {
                    let confName = candidateName ?? lang.t("der Kandidat", "the candidate")
                    Text(lang.t(
                        "Wie sicher bist du, dass \(confName) das Assessment schafft?",
                        "How confident are you that \(confName) will pass the assessment?"))
                        .font(.headline)
                        .foregroundStyle(Color.appPrimary)

                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { n in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    confidenceRating = confidenceRating == n ? nil : n
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(n)")
                                        .font(.title3.bold())
                                    Text(n == 1 ? lang.t("Kaum", "Unlikely") :
                                         n == 5 ? lang.t("Sicher!", "Sure!") : "")
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(confidenceRating == n
                                            ? Color(hex: "4A9EF8")
                                            : Color.appInputBG)
                                .foregroundStyle(confidenceRating == n ? .white : .white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            confidenceRating == n
                                            ? Color(hex: "4A9EF8").opacity(0)
                                            : Color.appBorder,
                                            lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Wish text
                VStack(alignment: .leading, spacing: 12) {
                    let wishName = candidateName ?? lang.t("dem Kandidaten", "the candidate")
                    Text(lang.t(
                        "Schreib \(wishName) einen persönlichen Wunsch! (optional)",
                        "Write \(wishName) a personal message! (optional)"))
                        .font(.headline)
                        .foregroundStyle(Color.appPrimary)

                    TextEditor(text: $wishText)
                        .frame(minHeight: 100)
                        .padding(12)
                        .background(Color.appInputBG)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Color.appPrimary)
                        .scrollContentBackground(.hidden)
                        .overlay(alignment: .topLeading) {
                            if wishText.isEmpty {
                                Text(lang.t(
                                    "z.B. Ich wünsche dir viel Erfolg, du packst das!",
                                    "e.g. I wish you all the best, you've got this!"))
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.3))
                                    .padding(.top, 20)
                                    .padding(.leading, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                .padding(18)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Submit button
                Button {
                    submitSurvey()
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text(lang.t("Absenden", "Submit"))
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "4A9EF8"))
                    .foregroundStyle(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .disabled(isSubmitting)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Submit

    private func submitSurvey() {
        isSubmitting = true
        Task {
            if case .selfAssessment = mode {
                await SurveyService.shared.submitSelfAssessment(
                    candidateId: auth.currentUser?.id ?? "",
                    responses: responses
                )
            } else if case .respondent(let token) = mode {
                let conf = confidenceRating
                let wish = wishText.trimmingCharacters(in: .whitespacesAndNewlines)
                try? await FeedbackService.shared.submitRespondentSurvey(
                    token: token,
                    name: respondentName,
                    relationship: respondentRelationship,
                    responses: responses,
                    confidenceRating: conf,
                    wishText: wish.isEmpty ? nil : wish
                )
            }
            await MainActor.run {
                isSubmitting = false
                withAnimation { isComplete = true }
            }
        }
    }

    // MARK: - Completion

    private var completionScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color(hex: "34C759"))
                .shadow(color: Color(hex: "34C759").opacity(0.4), radius: 20)

            VStack(spacing: 8) {
                Text(lang.t("Vielen Dank!", "Thank you!"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appPrimary)
                Text(mode.isRespondent
                     ? lang.t("Dein anonymes Feedback wurde übermittelt.", "Your anonymous feedback has been submitted.")
                     : lang.t("Self-Assessment abgeschlossen. Gehe zurück, um deinen Report-Status zu prüfen.",
                              "Self-assessment complete. Return to check your report status."))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer()
            Button { dismiss() } label: {
                Text(lang.t("Fertig", "Done"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "4A9EF8"))
                    .foregroundStyle(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}

extension SurveyMode {
    var isRespondent: Bool {
        if case .respondent = self { return true }
        return false
    }
}

#Preview {
    FeedbackSurveyView(mode: .selfAssessment)
        .environmentObject(AuthService.shared)
        .environmentObject(LanguageService.shared)
}
