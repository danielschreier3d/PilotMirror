import SwiftUI

struct InterviewSimulationView: View {
    @EnvironmentObject var lang: LanguageService

    private enum Phase {
        case setup
        case interview(questions: [InterviewQuestion], index: Int)
        case done(total: Int)
    }

    @State private var phase: Phase = .setup
    @State private var selectedSize: SessionSize = .medium
    @State private var showEndAlert = false

    var body: some View {
        ZStack {
            Color(hex: "0A1628").ignoresSafeArea()
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
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(lang.t(
                    "Wähle den Umfang der Session aus.",
                    "Choose the session size."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.bottom, 36)
            .padding(.horizontal, 24)

            HStack(spacing: 12) {
                ForEach(SessionSize.allCases, id: \.self) { size in
                    SizeCard(size: size, isSelected: selectedSize == size, isGerman: lang.isGerman) {
                        withAnimation(.spring(response: 0.3)) { selectedSize = size }
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                let questions = InterviewQuestion.randomSession(size: selectedSize)
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = .interview(questions: questions, index: 0)
                }
            } label: {
                Text(lang.t("Starten", "Start"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "4A9EF8"))
                    .foregroundStyle(.white)
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
        let question = questions[index]
        let total = questions.count
        let progress = Double(index + 1) / Double(total)
        let questionText = lang.isGerman ? question.de : question.en
        let answerText = lang.isGerman ? question.answerDE : question.answerEN
        let categoryLabel = lang.isGerman ? question.category.rawValue : question.category.labelEN

        return VStack(spacing: 0) {
            // Progress bar
            VStack(spacing: 6) {
                HStack {
                    Text("\(index + 1) / \(total)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Button(lang.t("Beenden", "End")) {
                        showEndAlert = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "4A9EF8"))
                }
                .padding(.horizontal, 20)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.12))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "4A9EF8"))
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 20)
            }
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 20) {
                // Category chip
                HStack(spacing: 6) {
                    Image(systemName: question.category.icon)
                        .font(.caption.weight(.semibold))
                    Text(categoryLabel)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color(hex: "4A9EF8"))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(hex: "4A9EF8").opacity(0.15))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: "4A9EF8").opacity(0.3), lineWidth: 1))

                // Question text
                Text(questionText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .fixedSize(horizontal: false, vertical: true)

                // Answer card (only for showsAnswer categories)
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
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "34C759").opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color(hex: "34C759").opacity(0.35), lineWidth: 1.5)
                            )
                    )
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }

            Spacer()

            // Navigation buttons
            HStack(spacing: 16) {
                Button {
                    guard index > 0 else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .interview(questions: questions, index: index - 1)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text(lang.t("Zurück", "Back"))
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(index > 0 ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                    .foregroundStyle(index > 0 ? .white : .white.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(index > 0 ? 0.15 : 0.05), lineWidth: 1)
                    )
                }
                .disabled(index == 0)

                Button {
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "4A9EF8"))
                    .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(lang.t(
                        "\(total) Fragen gestellt",
                        "\(total) questions asked"
                    ))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = .setup
                }
            } label: {
                Text(lang.t("Neue Session", "New Session"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "4A9EF8"))
                    .foregroundStyle(.white)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Text(size.countLabel)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color(hex: "4A9EF8") : .white)

                Text(isGerman ? size.labelDE : size.labelEN)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(isGerman ? size.descriptionDE : size.descriptionEN)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: "4A9EF8"))
                        .font(.body)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.white.opacity(0.25))
                        .font(.body)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                isSelected ? Color(hex: "4A9EF8").opacity(0.8) : Color.white.opacity(0.12),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
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
}
