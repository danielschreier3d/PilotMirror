import SwiftUI

struct FeedbackStatusView: View {
    @ObservedObject var feedbackService = FeedbackService.shared
    @ObservedObject var surveyService = SurveyService.shared
    @ObservedObject var aiService = AIAnalysisService.shared
    @EnvironmentObject var auth: AuthService

    @State private var showSelfAssessment = false
    @State private var showResults = false
    @State private var isRefreshing = false

    let minimumResponses = 5
    let targetResponses = 12

    var responseCount: Int { feedbackService.feedbackLink?.responseCount ?? 0 }
    var progress: Double { Double(responseCount) / Double(targetResponses) }
    var canAnalyze: Bool { responseCount >= minimumResponses && surveyService.selfResponses.count >= 5 }

    var body: some View {
        ZStack {
            Color(hex: "0A1628").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Feedback Status")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if let type = auth.currentUser?.assessmentType {
                            Text(type.rawValue)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "4A9EF8"))
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .background(Color(hex: "4A9EF8").opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 24)

                    // Progress card
                    progressCard

                    // Self-assessment card
                    selfAssessmentCard

                    // Analyze button
                    if canAnalyze {
                        analyzeButton
                    }

                    // DEBUG: Demo shortcut
                    demoButton

                    Spacer(minLength: 40)
                }
            }
            .refreshable {
                await feedbackService.refreshStatus()
            }
        }
        .sheet(isPresented: $showSelfAssessment) {
            FeedbackSurveyView(mode: .selfAssessment)
                .environmentObject(auth)
        }
        .navigationDestination(isPresented: $showResults) {
            ResultsView()
                .environmentObject(auth)
        }
    }

    private var progressCard: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(responseCount) of \(targetResponses) responses")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(responseCount < minimumResponses
                         ? "Need \(minimumResponses - responseCount) more to unlock analysis"
                         : "Enough responses to generate your report!")
                        .font(.caption)
                        .foregroundStyle(responseCount < minimumResponses ? .white.opacity(0.5) : Color(hex: "34C759"))
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color(hex: "4A9EF8"), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progress)
                    Text("\(responseCount)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.1))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(colors: [Color(hex: "4A9EF8"), Color(hex: "34C759")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(0, geo.size.width * progress), height: 10)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 10)

            // Milestone markers
            HStack {
                Text("0")
                Spacer()
                Text("5 min")
                    .foregroundStyle(responseCount >= 5 ? Color(hex: "34C759") : .white.opacity(0.4))
                Spacer()
                Text("12 ideal")
                    .foregroundStyle(responseCount >= 12 ? Color(hex: "34C759") : .white.opacity(0.4))
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.4))
        }
        .padding(20)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private var selfAssessmentCard: some View {
        let completed = surveyService.selfResponses.count >= 5
        return Button {
            if !completed { showSelfAssessment = true }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: completed ? "checkmark.circle.fill" : "person.fill.questionmark")
                    .font(.system(size: 28))
                    .foregroundStyle(completed ? Color(hex: "34C759") : Color(hex: "FF9F0A"))
                    .frame(width: 52, height: 52)
                    .background((completed ? Color(hex: "34C759") : Color(hex: "FF9F0A")).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Self-Assessment")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(completed ? "Completed ✓" : "Required — answer the same survey about yourself")
                        .font(.caption)
                        .foregroundStyle(completed ? Color(hex: "34C759") : .white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if !completed {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(16)
            .background(.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var analyzeButton: some View {
        Button {
            Task {
                let assessment = auth.currentUser?.assessmentType?.rawValue ?? "General"
                await aiService.analyze(
                    assessmentType: assessment,
                    selfResponses: surveyService.selfResponses,
                    externalResponses: [] // TODO: fetch from Supabase
                )
                if aiService.result != nil { showResults = true }
            }
        } label: {
            Group {
                if aiService.isAnalyzing {
                    HStack {
                        ProgressView().tint(.white)
                        Text("Analyzing…").foregroundStyle(.white)
                    }
                } else {
                    Label("Generate AI Report", systemImage: "sparkles")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(colors: [Color(hex: "4A9EF8"), Color(hex: "6B5EE4")],
                               startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .disabled(aiService.isAnalyzing)
    }

    // MARK: - Demo shortcut

    private var demoButton: some View {
        Button {
            loadMockData()
            showResults = true
        } label: {
            Label("Demo: Show Analysis (5 responses)", systemImage: "flask.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.vertical, 10)
        }
    }

    private func loadMockData() {
        // Simulate 7 external responses
        let link = feedbackService.feedbackLink ?? FeedbackLink(
            id: UUID().uuidString,
            candidateId: auth.currentUser?.id ?? "demo",
            token: "demo-token",
            createdAt: Date(),
            responseCount: 7
        )
        feedbackService.feedbackLink = FeedbackLink(
            id: link.id, candidateId: link.candidateId,
            token: link.token, createdAt: link.createdAt, responseCount: 7
        )

        // Simulate self responses
        surveyService.selfResponses = [
            "q1":  .multipleChoice(["ruhig", "analytisch", "verantwortungsbewusst", "strukturiert"]),
            "q2":  .singleChoice("Nach sorgfältiger Analyse"),
            "q3":  .singleChoice("Ideen einzubringen"),
            "q4":  .singleChoice("Ruhig & lösungsorientiert"),
            "q5":  .rating(4),
            "q6":  .rating(4),
            "q7":  .rating(5),
            "q8":  .rating(3),
            "q9":  .rating(5),
            "q10": .text("Sehr zuverlässig, immer gut vorbereitet"),
            "q11": .text("Ruhig unter Druck, gibt anderen Stabilität"),
            "q12": .text("Wenn es komplex wird — behält den Überblick"),
            "q13": .text("Manchmal zu lange in der Analyse, bevor ich handele"),
            "q14": .text("Trete in Gruppen nicht immer proaktiv auf"),
            "q15": .text("Kann ungeduldig werden, wenn Dinge schlecht organisiert sind"),
            "q16": .text(""),
            "q17": .text("Nehme Feedback gut an, manchmal etwas defensiv bei ungerechter Kritik"),
            "q18": .text(""),
        ]

        // Load mock AI result directly
        aiService.loadMockResult(
            assessmentType: auth.currentUser?.assessmentType?.rawValue ?? "General Pilot Assessment"
        )
    }
}
