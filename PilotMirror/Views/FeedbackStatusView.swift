import SwiftUI

struct FeedbackStatusView: View {
    @ObservedObject var feedbackService = FeedbackService.shared
    @ObservedObject var surveyService = SurveyService.shared
    @ObservedObject var aiService = AIAnalysisService.shared
    @EnvironmentObject var auth: AuthService

    @State private var showSelfAssessment = false
    @State private var showResults = false
    @State private var isCreatingLink = false
    @State private var showShareSheet = false
    @State private var copied = false

    let minimumResponses = 5
    let targetResponses = 12

    var selfDone: Bool { surveyService.selfResponses.count >= 5 }
    var responseCount: Int { feedbackService.feedbackLink?.responseCount ?? 0 }
    var linkDone: Bool { responseCount >= minimumResponses }
    var canAnalyze: Bool { selfDone && linkDone }

    var body: some View {
        ZStack {
            Color(hex: "0A1628").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    step1Card
                    step2Card
                    step3Card
                    demoButton
                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .refreshable { await feedbackService.refreshStatus() }
        }
        .sheet(isPresented: $showSelfAssessment) {
            FeedbackSurveyView(mode: .selfAssessment).environmentObject(auth)
        }
        .sheet(isPresented: $showShareSheet) {
            if let link = feedbackService.feedbackLink {
                ShareSheet(items: [link.shareURL])
            }
        }
        .navigationDestination(isPresented: $showResults) {
            ResultsView().environmentObject(auth)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("Dein Assessment-Plan")
                .font(.system(size: 24, weight: .bold, design: .rounded))
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
    }

    // MARK: - Step 1: Self-Assessment

    private var step1Card: some View {
        stepCard(
            number: 1,
            title: "Self-Assessment ausfüllen",
            subtitle: selfDone ? "Abgeschlossen" : "Beantworte denselben Fragebogen über dich selbst",
            done: selfDone,
            locked: false
        ) {
            if !selfDone {
                actionButton("Jetzt starten", icon: "pencil.and.list.clipboard", color: "4A9EF8") {
                    showSelfAssessment = true
                }
            }
        }
    }

    // MARK: - Step 2: Link teilen

    private var step2Card: some View {
        stepCard(
            number: 2,
            title: "Link an mindestens 5 Personen senden",
            subtitle: linkDone
                ? "\(responseCount) Rückmeldungen erhalten ✓"
                : feedbackService.feedbackLink == nil
                    ? "Erstelle deinen persönlichen Feedback-Link"
                    : "\(responseCount) von \(minimumResponses) Rückmeldungen — \(minimumResponses - responseCount) fehlen noch",
            done: linkDone,
            locked: false
        ) {
            if let link = feedbackService.feedbackLink {
                VStack(spacing: 10) {
                    // Response progress bar
                    if !linkDone {
                        responseProgressBar
                    }

                    // URL copy row
                    HStack {
                        Text(link.shareURLString)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Color(hex: "4A9EF8"))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = link.shareURLString
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copied = false }
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundStyle(copied ? Color(hex: "34C759") : Color(hex: "4A9EF8"))
                        }
                    }
                    .padding(12)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Share buttons
                    HStack(spacing: 10) {
                        shareIconButton("WhatsApp", icon: "message.fill", color: "34C759") { openWhatsApp(link.shareURLString) }
                        shareIconButton("iMessage", icon: "message.fill", color: "4A9EF8") { openMessages(link.shareURLString) }
                        shareIconButton("E-Mail", icon: "envelope.fill", color: "FF9F0A") { openMail(link.shareURLString) }
                        shareIconButton("Mehr", icon: "square.and.arrow.up", color: "8E8E93") { showShareSheet = true }
                    }
                }
            } else {
                actionButton(
                    isCreatingLink ? "Wird erstellt…" : "Link erstellen",
                    icon: "link.badge.plus",
                    color: selfDone ? "4A9EF8" : "8E8E93"
                ) {
                    guard selfDone else { return }
                    Task {
                        isCreatingLink = true
                        let candidateId = auth.currentUser?.id ?? UUID().uuidString
                        _ = try? await feedbackService.createFeedbackLink(candidateId: candidateId)
                        isCreatingLink = false
                    }
                }
                .disabled(isCreatingLink || !selfDone)
                if !selfDone {
                    Text("Erst Self-Assessment abschließen")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var responseProgressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08)).frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "4A9EF8"), Color(hex: "34C759")],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * Double(responseCount) / Double(minimumResponses)), height: 8)
                        .animation(.spring(response: 0.5), value: responseCount)
                }
            }
            .frame(height: 8)
            HStack {
                Text("0")
                Spacer()
                Text("5 Minimum")
                    .foregroundStyle(responseCount >= 5 ? Color(hex: "34C759") : .white.opacity(0.4))
                Spacer()
                Text("12 Ideal")
                    .foregroundStyle(responseCount >= 12 ? Color(hex: "34C759") : .white.opacity(0.4))
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Step 3: Analyse

    private var step3Card: some View {
        stepCard(
            number: 3,
            title: "KI-Analyse starten",
            subtitle: canAnalyze
                ? "Alle Voraussetzungen erfüllt — Report kann erstellt werden"
                : "Verfügbar sobald Self-Assessment und 5 Rückmeldungen vorliegen",
            done: aiService.result != nil,
            locked: !canAnalyze
        ) {
            if canAnalyze {
                actionButton(
                    aiService.isAnalyzing ? "Analysiere…" : "Report erstellen",
                    icon: "sparkles",
                    color: "6B5EE4",
                    gradient: true
                ) {
                    Task {
                        let assessment = auth.currentUser?.assessmentType?.rawValue ?? "General"
                        await aiService.analyze(
                            assessmentType: assessment,
                            selfResponses: surveyService.selfResponses,
                            externalResponses: []
                        )
                        if aiService.result != nil { showResults = true }
                    }
                }
                .disabled(aiService.isAnalyzing)
            }
            if aiService.result != nil {
                actionButton("Report anzeigen", icon: "doc.text.fill", color: "34C759") {
                    showResults = true
                }
            }
        }
    }

    // MARK: - Shared components

    private func stepCard<Content: View>(
        number: Int,
        title: String,
        subtitle: String,
        done: Bool,
        locked: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                // Step indicator
                ZStack {
                    Circle()
                        .fill(done ? Color(hex: "34C759") : locked ? .white.opacity(0.06) : Color(hex: "4A9EF8").opacity(0.2))
                        .frame(width: 38, height: 38)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "34C759"))
                    } else {
                        Text("\(number)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(locked ? .white.opacity(0.25) : Color(hex: "4A9EF8"))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(locked ? .white.opacity(0.35) : .white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(done ? Color(hex: "34C759") : locked ? .white.opacity(0.25) : .white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            if !locked {
                content()
            }
        }
        .padding(18)
        .background(done ? Color(hex: "34C759").opacity(0.07) : .white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(done ? Color(hex: "34C759").opacity(0.3) : .clear, lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private func actionButton(
        _ title: String, icon: String, color: String, gradient: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    gradient
                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "4A9EF8"), Color(hex: color)],
                                                        startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color(hex: color).opacity(0.85))
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func shareIconButton(_ label: String, icon: String, color: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: color))
                    .frame(width: 46, height: 46)
                    .background(Color(hex: color).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Demo

    private var demoButton: some View {
        Button {
            loadMockData()
            showResults = true
        } label: {
            Label("Demo: Analyse anzeigen", systemImage: "flask.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.vertical, 10)
        }
    }

    // MARK: - Share helpers

    private func openWhatsApp(_ url: String) {
        let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        let msg = "Hey! Ich würde mich über dein anonymes Feedback für mein Piloten-Assessment freuen:\n\(encoded)"
        let wa = "whatsapp://send?text=\(msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let u = URL(string: wa) { UIApplication.shared.open(u) }
    }

    private func openMessages(_ url: String) {
        let sms = "sms:&body=Hey! Kannst du mir kurz anonymes Feedback geben? Dauert nur 3 Minuten: \(url)"
        if let u = URL(string: sms.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sms) {
            UIApplication.shared.open(u)
        }
    }

    private func openMail(_ url: String) {
        let body = "Hi,\n\nich bereite mich auf mein Piloten-Assessment vor und würde mich sehr über dein anonymes Feedback freuen.\nDauert weniger als 3 Minuten:\n\(url)\n\nVielen Dank!"
        let mail = "mailto:?subject=Feedback-Bitte%20–%20PilotMirror&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let u = URL(string: mail) { UIApplication.shared.open(u) }
    }

    // MARK: - Mock data

    private func loadMockData() {
        let link = feedbackService.feedbackLink ?? FeedbackLink(
            id: UUID().uuidString, candidateId: auth.currentUser?.id ?? "demo",
            token: "demo-token", createdAt: Date(), responseCount: 7
        )
        feedbackService.feedbackLink = FeedbackLink(
            id: link.id, candidateId: link.candidateId,
            token: link.token, createdAt: link.createdAt, responseCount: 7
        )
        surveyService.selfResponses = [
            "q1":  .multipleChoice(["ruhig", "analytisch", "verantwortungsbewusst", "strukturiert"]),
            "q2":  .singleChoice("Nach sorgfältiger Analyse"),
            "q3":  .singleChoice("Ideen einzubringen"),
            "q4":  .singleChoice("Ruhig & lösungsorientiert"),
            "q5":  .rating(4), "q6": .rating(4), "q7": .rating(5),
            "q8":  .rating(3), "q9": .rating(5),
            "q10": .text("Sehr zuverlässig, immer gut vorbereitet"),
            "q11": .text("Ruhig unter Druck, gibt anderen Stabilität"),
            "q12": .text("Wenn es komplex wird — behält den Überblick"),
            "q13": .text("Manchmal zu lange in der Analyse, bevor ich handele"),
            "q14": .text("Trete in Gruppen nicht immer proaktiv auf"),
            "q15": .text("Kann ungeduldig werden, wenn Dinge schlecht organisiert sind"),
            "q16": .text(""), "q17": .text("Nehme Feedback gut an"),  "q18": .text(""),
        ]
        aiService.loadMockResult(assessmentType: auth.currentUser?.assessmentType?.rawValue ?? "General Pilot Assessment")
    }
}
