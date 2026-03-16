import SwiftUI

struct InterviewSimulationView: View {
    @EnvironmentObject var lang: LanguageService
    @EnvironmentObject var auth: AuthService

    private enum Phase {
        case setup
        case interview(questions: [InterviewQuestion], index: Int)
        case done(total: Int)
    }

    @State private var phase: Phase = .setup
    @State private var selectedSize: SessionSize = .medium
    @State private var showEndAlert  = false
    @State private var showFollowUps = false

    private var aiService: AIAnalysisService { AIAnalysisService.shared }

    private var flightLicenses: [User.FlightLicense] {
        auth.currentUser?.flightLicenses ?? []
    }
    private var assessmentType: User.AssessmentType? {
        auth.currentUser?.assessmentType
    }
    private var hasAIQuestions: Bool {
        !aiService.cachedInterviewQuestions.isEmpty
    }

    private func buildAIQuestions() -> [InterviewQuestion] {
        aiService.cachedInterviewQuestions.enumerated().map { i, text in
            InterviewQuestion(id: "ai_\(i)", category: .personality,
                              de: text, en: text,
                              answerDE: nil, answerEN: nil,
                              isAIGenerated: true)
        }
    }

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()
            switch phase {
            case .setup:
                setupView
            case .interview(let questions, let index):
                interviewView(questions: questions, index: index)
            case .done(let total):
                doneView(total: total)
            }
        }
        .navigationTitle(lang.t("Interview Simulation", "Interview Simulation"))
        .navigationBarBackButtonHidden(true)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Setup Phase
    // ─────────────────────────────────────────────────────────────────────────

    private var setupView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color(hex: "4A9EF8"))
                    .padding(.bottom, 4)

                Text(lang.t("Interview Simulation", "Interview Simulation"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appPrimary)
                    .multilineTextAlignment(.center)

                Text(lang.t("Wähle den Umfang der Session aus.",
                            "Choose the session size."))
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondary)
                    .multilineTextAlignment(.center)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "person.wave.2.fill")
                        .foregroundStyle(Color(hex: "4A9EF8"))
                        .font(.subheadline)
                        .padding(.top, 1)
                    Text(lang.t(
                        "Such dir jemanden, der dich in einer simulierten Interviewsituation mit den Fragen unseres Simulators interviewt — so nah an der Realität wie möglich.",
                        "Find someone to interview you in a simulated interview situation using our simulator's questions — as close to the real thing as possible."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(Color.appPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "4A9EF8").opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color(hex: "4A9EF8").opacity(0.25), lineWidth: 1))
                )
                .padding(.top, 4)

                if let type = assessmentType {
                    HStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.caption.weight(.semibold))
                        Text(type.rawValue)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color(hex: "4A9EF8"))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color(hex: "4A9EF8").opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.top, 4)
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 36)
            .padding(.horizontal, 24)

            HStack(spacing: 12) {
                ForEach(SessionSize.allCases, id: \.self) { size in
                    SizeCard(
                        size: size,
                        isSelected: selectedSize == size,
                        isGerman: lang.isGerman,
                        hasAIQuestions: hasAIQuestions
                    ) {
                        withAnimation(.spring(response: 0.3)) { selectedSize = size }
                    }
                }
            }
            .padding(.horizontal, 20)

            if hasAIQuestions {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                    Text(lang.t(
                        "\(selectedSize.aiQuestionCount) KI-Fragen aus deinem Profil enthalten",
                        "\(selectedSize.aiQuestionCount) AI questions from your profile included"
                    ))
                    .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color(hex: "FF9F0A"))
                .padding(.top, 16)
            }

            Spacer()

            Button {
                let questions = InterviewQuestion.randomSession(
                    size: selectedSize,
                    flightLicenses: flightLicenses,
                    assessmentType: assessmentType,
                    aiQuestions: buildAIQuestions()
                )
                showFollowUps = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = .interview(questions: questions, index: 0)
                }
            } label: {
                Text(lang.t("Starten", "Start"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "4A9EF8"))
                    .foregroundStyle(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Interview Phase
    // ─────────────────────────────────────────────────────────────────────────

    private func interviewView(questions: [InterviewQuestion], index: Int) -> some View {
        let question     = questions[index]
        let total        = questions.count
        let progress     = Double(index + 1) / Double(total)
        let questionText = lang.isGerman ? question.de : question.en
        let answerText   = lang.isGerman ? question.answerDE : question.answerEN
        let categoryLabel = lang.isGerman ? question.category.rawValue : question.category.labelEN
        let followUps    = lang.isGerman ? question.followUpsDE : question.followUpsEN

        return VStack(spacing: 0) {

            // Progress bar + end button
            VStack(spacing: 6) {
                HStack {
                    Text("\(index + 1) / \(total)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appSecondary)
                    Spacer()
                    Button(lang.t("Beenden", "End")) { showEndAlert = true }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "4A9EF8"))
                }
                .padding(.horizontal, 20)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.appBorder).frame(height: 6)
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: "4A9EF8"))
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 20)
            }
            .padding(.top, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // Category chip + AI badge
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: question.category.icon)
                                .font(.caption.weight(.semibold))
                            Text(categoryLabel)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color(hex: "4A9EF8"))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color(hex: "4A9EF8").opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color(hex: "4A9EF8").opacity(0.3), lineWidth: 1))

                        if question.isAIGenerated {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles").font(.caption2)
                                Text(lang.t("KI-Frage", "AI Question"))
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(Color(hex: "FF9F0A"))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color(hex: "FF9F0A").opacity(0.15))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color(hex: "FF9F0A").opacity(0.3), lineWidth: 1))
                        }
                    }
                    .padding(.top, 20)

                    // Question text
                    Text(questionText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.appPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)

                    // Answer card
                    if let answer = answerText, question.category.showsAnswer {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(hex: "34C759"))
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.t("Antwort", "Answer"))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color(hex: "34C759").opacity(0.8))
                                Text(answer)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.appPrimary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "34C759").opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color(hex: "34C759").opacity(0.35), lineWidth: 1.5))
                        )
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }

                    // Follow-ups
                    if let fups = followUps, !fups.isEmpty {
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    showFollowUps.toggle()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption.weight(.semibold))
                                    Text(lang.t(
                                        "Nachfragen (\(fups.count))",
                                        "Follow-ups (\(fups.count))"
                                    ))
                                    .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Image(systemName: showFollowUps ? "chevron.up" : "chevron.down")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(Color(hex: "4A9EF8"))
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)

                            if showFollowUps {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(fups, id: \.self) { followUp in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "arrow.turn.down.right")
                                                .font(.caption)
                                                .foregroundStyle(Color.appTertiary)
                                                .padding(.top, 2)
                                            Text(followUp)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.appPrimary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "4A9EF8").opacity(0.07))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color(hex: "4A9EF8").opacity(0.22), lineWidth: 1))
                        )
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 20)
            }

            Spacer(minLength: 0)

            // Navigation
            HStack(spacing: 16) {
                Button {
                    guard index > 0 else { return }
                    showFollowUps = false
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .interview(questions: questions, index: index - 1)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text(lang.t("Zurück", "Back"))
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(index > 0 ? Color.appInputBG : Color.appBorder.opacity(0.3))
                    .foregroundStyle(index > 0 ? Color.appPrimary : Color.appTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.appBorder, lineWidth: 1))
                }
                .disabled(index == 0)

                Button {
                    showFollowUps = false
                    if index < total - 1 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            phase = .interview(questions: questions, index: index + 1)
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            phase = .done(total: total)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(index < total - 1 ? lang.t("Weiter", "Next") : lang.t("Fertig", "Done"))
                        Image(systemName: index < total - 1 ? "chevron.right" : "checkmark")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Color(hex: "4A9EF8"))
                    .foregroundStyle(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .alert(lang.t("Interview beenden?", "End interview?"), isPresented: $showEndAlert) {
            Button(lang.t("Abbrechen", "Cancel"), role: .cancel) {}
            Button(lang.t("Beenden", "End"), role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = .done(total: index + 1)
                }
            }
        } message: {
            Text(lang.t(
                "Du hast \(index + 1) von \(total) Fragen gestellt.",
                "You have asked \(index + 1) of \(total) questions."
            ))
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Done Phase
    // ─────────────────────────────────────────────────────────────────────────

    private func doneView(total: Int) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color(hex: "34C759"))

                VStack(spacing: 8) {
                    Text(lang.t("Interview abgeschlossen!", "Interview complete!"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appPrimary)
                        .multilineTextAlignment(.center)
                    Text(lang.t("\(total) Fragen gestellt", "\(total) questions asked"))
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondary)
                }
            }
            Spacer()
            Button {
                showFollowUps = false
                withAnimation(.easeInOut(duration: 0.3)) { phase = .setup }
            } label: {
                Text(lang.t("Neue Session", "New Session"))
                    .font(.headline)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Color(hex: "4A9EF8"))
                    .foregroundStyle(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SizeCard
// ─────────────────────────────────────────────────────────────────────────────

private struct SizeCard: View {
    let size: SessionSize
    let isSelected: Bool
    let isGerman: Bool
    let hasAIQuestions: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Text(size.totalCount(hasAIQuestions: hasAIQuestions))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color(hex: "4A9EF8") : Color.appPrimary)

                Text(isGerman ? size.labelDE : size.labelEN)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appPrimary)

                Text(isGerman ? size.descriptionDE : size.descriptionEN)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if hasAIQuestions {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles").font(.caption2)
                        Text("+\(size.aiQuestionCount) KI")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Color(hex: "FF9F0A"))
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color(hex: "4A9EF8") : Color.appTertiary)
                    .font(.body)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18).padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Color.appCard : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            isSelected ? Color(hex: "4A9EF8").opacity(0.8) : Color.appBorder,
                            lineWidth: isSelected ? 1.5 : 1))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        InterviewSimulationView()
            .navigationBarTitleDisplayMode(.inline)
    }
    .environmentObject(LanguageService.shared)
    .environmentObject(AuthService.shared)
}
