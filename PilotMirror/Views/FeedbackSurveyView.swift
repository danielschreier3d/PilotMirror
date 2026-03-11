import SwiftUI

enum SurveyMode {
    case respondent(token: String)
    case selfAssessment
}

struct FeedbackSurveyView: View {
    let mode: SurveyMode
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var currentIndex = 0
    @State private var responses: [String: AnswerValue] = [:]
    @State private var respondentName = ""
    @State private var respondentRelationship = Respondent.RelationshipType.friend
    @State private var showIntro = true
    @State private var isSubmitting = false
    @State private var isComplete = false

    var questions: [Question] { Question.surveyQuestions }
    var currentQuestion: Question { questions[currentIndex] }
    var progress: Double { Double(currentIndex) / Double(questions.count) }

    var body: some View {
        ZStack {
            Color(hex: "0A1628").ignoresSafeArea()

            if isComplete {
                completionScreen
            } else if showIntro {
                introScreen
            } else {
                questionScreen
            }
        }
    }

    // MARK: - Intro

    private var introScreen: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: mode.isRespondent ? "lock.shield.fill" : "person.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color(hex: "4A9EF8"))

                Text(mode.isRespondent ? "Your feedback is anonymous" : "Rate yourself honestly")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(mode.isRespondent
                     ? "Your name will never be shown to the candidate. Your answers are confidential and used only to generate an anonymous report."
                     : "Answer the same questions as your feedback providers. Be as honest as possible — this comparison is the core of your report.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal)

                Text("Takes less than 3 minutes")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "34C759"))
            }

            if mode.isRespondent {
                // Collect respondent info
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color(hex: "4A9EF8"))
                        TextField("Your first name", text: $respondentName)
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                    }
                    .padding()
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Picker("Relationship", selection: $respondentRelationship) {
                        ForEach(Respondent.RelationshipType.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color(hex: "4A9EF8"))
                    .padding()
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }

            Button {
                withAnimation { showIntro = false }
            } label: {
                Text("Start Survey")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "4A9EF8"))
                    .foregroundStyle(.white)
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
                    Text("Question \(currentIndex + 1) of \(questions.count)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text(currentQuestion.sectionTitle)
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

            // Question card
            ScrollView {
                QuestionCard(
                    question: currentQuestion,
                    answer: responses[currentQuestion.id],
                    onAnswer: { value in
                        responses[currentQuestion.id] = value
                    }
                )
                .padding()
                .id(currentIndex)
            }

            // Navigation
            HStack(spacing: 12) {
                if currentIndex > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { currentIndex -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 52, height: 52)
                            .background(.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                }

                Button {
                    if currentIndex < questions.count - 1 {
                        withAnimation(.easeInOut(duration: 0.2)) { currentIndex += 1 }
                    } else {
                        submitSurvey()
                    }
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text(currentIndex < questions.count - 1 ? "Next" : "Submit")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canAdvance ? Color(hex: "4A9EF8") : .white.opacity(0.12))
                    .foregroundStyle(.white)
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
        if q.type == .openText { return true } // open text is optional
        return responses[q.id] != nil
    }

    private func submitSurvey() {
        isSubmitting = true
        Task {
            if case .selfAssessment = mode {
                await SurveyService.shared.submitSelfAssessment(
                    candidateId: auth.currentUser?.id ?? "",
                    responses: responses
                )
            } else {
                try? await FeedbackService.shared.submitResponses(responses, respondentId: UUID().uuidString)
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
                Text("Thank you!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(mode.isRespondent
                     ? "Your anonymous feedback has been submitted."
                     : "Self-assessment complete. Return to check your report status.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "4A9EF8"))
                    .foregroundStyle(.white)
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
}
