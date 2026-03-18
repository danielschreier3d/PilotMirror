import SwiftUI

struct InterviewSimulationView: View {
    @EnvironmentObject var lang: LanguageService
    @EnvironmentObject var auth: AuthService

    private enum Phase {
        case locked
        case setup
        case interview(questions: [InterviewQuestion], index: Int)
        case done(total: Int)
    }

    @State private var phase: Phase = .setup
    @State private var selectedSize: SessionSize = .medium
    @State private var showEndAlert  = false
    @State private var showFollowUps = false
    @State private var aiHint:        String?  = nil
    @State private var isLoadingHint: Bool     = false

    private var aiService: AIAnalysisService { AIAnalysisService.shared }
    private var feedback:  FeedbackService   { FeedbackService.shared }

    private var flightLicenses: [User.FlightLicense] {
        auth.currentUser?.flightLicenses ?? []
    }
    private var assessmentType: User.AssessmentType? {
        auth.currentUser?.assessmentType
    }
    private var hasAIQuestions: Bool {
        !aiService.cachedInterviewQuestions.isEmpty
    }
    private var respondentCount: Int {
        feedback.feedbackLink?.responseCount ?? feedback.respondents.count
    }
    private var interviewRunCount: Int {
        get { UserDefaults.standard.integer(forKey: "pm_interview_run_count") }
    }
    private func incrementRunCount() {
        let newCount = interviewRunCount + 1
        UserDefaults.standard.set(newCount, forKey: "pm_interview_run_count")
        Task {
            guard let userId = auth.currentUser?.id else { return }
            try? await SupabaseClient.shared.update(
                table: "users",
                filters: ["id": "eq.\(userId)"],
                body: ["interview_run_count": newCount]
            )
        }
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
            case .locked:
                lockedView
            case .setup:
                setupView
            case .interview(let questions, let index):
                interviewView(questions: questions, index: index)
            case .done(let total):
                doneView(total: total)
            }
        }
        .navigationTitle(lang.t("Interview Simulation", "Interview Simulation"))
        .navigationBarBackButtonHidden({
            if case .interview = phase { return true }
            return false
        }())
        .onAppear {
            if respondentCount < 5 { phase = .locked }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Locked Phase
    // ─────────────────────────────────────────────────────────────────────────

    private var lockedView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color(hex: "4A9EF8").opacity(0.7))

                VStack(spacing: 8) {
                    Text(lang.t("Interview gesperrt", "Interview Locked"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appPrimary)
                    Text(lang.t(
                        "Du benötigst mindestens 5 ausgefüllte Umfragen, um die Interview-Simulation freizuschalten. So werden deine Fragen auf dein echtes Profil abgestimmt.",
                        "You need at least 5 completed surveys to unlock the interview simulation. This ensures your questions are tailored to your actual profile."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                }

                // Progress indicator
                VStack(spacing: 10) {
                    HStack {
                        Text(lang.t("Umfrageergebnisse", "Survey responses"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appSecondary)
                        Spacer()
                        Text("\(respondentCount) / 5")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(respondentCount >= 5 ? Color(hex: "34C759") : Color(hex: "4A9EF8"))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.appBorder).frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(respondentCount >= 5 ? Color(hex: "34C759") : Color(hex: "4A9EF8"))
                                .frame(width: geo.size.width * min(Double(respondentCount) / 5.0, 1.0), height: 8)
                        }
                    }.frame(height: 8)
                }
                .padding(16)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.appBorder, lineWidth: 1))
            }
            .padding(.horizontal, 28)
            Spacer()
        }
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
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text(lang.t(
                        "Fülle zuerst die Selbsteinschätzung aus — danach werden personalisierte KI-Fragen ergänzt.",
                        "Complete the self-assessment first — personalised AI questions will then be added."
                    ))
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                }
                .foregroundStyle(Color.appSecondary)
                .padding(12)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.appBorder, lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            Spacer()

            // Run counter chip
            let runCount = interviewRunCount
            HStack(spacing: 6) {
                Image(systemName: runCount >= 3 ? "checkmark.seal.fill" : "number.circle.fill")
                    .font(.caption.weight(.semibold))
                Text(runCount == 0
                     ? lang.t("Erster Durchgang", "First run")
                     : lang.t("Durchgang \(runCount + 1) · Pool \((runCount % 3) + 1)/3",
                               "Run \(runCount + 1) · Pool \((runCount % 3) + 1)/3"))
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(runCount >= 3 ? Color(hex: "34C759") : Color.appSecondary)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Button {
                let questions = InterviewQuestion.randomSession(
                    size: selectedSize,
                    poolIndex: interviewRunCount,
                    flightLicenses: flightLicenses,
                    assessmentType: assessmentType,
                    aiQuestions: buildAIQuestions()
                )
                aiHint = nil
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

                    // AI hint button (knowledge categories only)
                    if question.category.supportsAIHint && !question.category.showsAnswer {
                        VStack(spacing: 0) {
                            Button {
                                guard !isLoadingHint else { return }
                                if aiHint != nil { aiHint = nil; return }
                                isLoadingHint = true
                                Task {
                                    defer { isLoadingHint = false }
                                    let q = lang.isGerman ? question.de : question.en
                                    aiHint = try? await AIAnalysisService.shared
                                        .fetchInterviewHint(question: q, language: lang.isGerman ? "de" : "en")
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if isLoadingHint {
                                        ProgressView().scaleEffect(0.8).tint(Color(hex: "FF9F0A"))
                                    } else {
                                        Image(systemName: aiHint == nil ? "sparkles" : "sparkles.slash")
                                            .font(.caption.weight(.semibold))
                                    }
                                    Text(aiHint == nil
                                         ? lang.t("KI-Musterantwort anzeigen", "Show AI model answer")
                                         : lang.t("KI-Antwort ausblenden", "Hide AI answer"))
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(Color(hex: "FF9F0A"))
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(Color(hex: "FF9F0A").opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color(hex: "FF9F0A").opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            if let hint = aiHint {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(Color(hex: "FF9F0A"))
                                        .font(.caption.weight(.bold))
                                        .padding(.top, 2)
                                    Text(hint)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(hex: "FF9F0A").opacity(0.08))
                                        .overlay(RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(Color(hex: "FF9F0A").opacity(0.3), lineWidth: 1))
                                )
                                .padding(.top, 10)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 24)
                        .animation(.easeInOut(duration: 0.22), value: aiHint)
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
                    showFollowUps = false; aiHint = nil
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
                    showFollowUps = false; aiHint = nil
                    if index < total - 1 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            phase = .interview(questions: questions, index: index + 1)
                        }
                    } else {
                        incrementRunCount()
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
                incrementRunCount()
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
                    let runs = interviewRunCount
                    Text(runs >= 3
                         ? lang.t("✓ Mindestens 3 Durchgänge absolviert", "✓ At least 3 runs completed")
                         : lang.t("Durchgang \(runs) von 3", "Run \(runs) of 3"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(runs >= 3 ? Color(hex: "34C759") : Color.appSecondary)
                        .padding(.top, 2)
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
