import SwiftUI

struct FeedbackStatusView: View {
    @ObservedObject var feedbackService = FeedbackService.shared
    @ObservedObject var surveyService = SurveyService.shared
    @ObservedObject var aiService = AIAnalysisService.shared
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var lang: LanguageService

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

    // True when a saved report exists but new responses have come in since it was generated
    var hasNewResponses: Bool {
        guard let r = aiService.result, r.respondentCount > 0 else { return false }
        return responseCount > r.respondentCount
    }
    // True when report is up to date (no new responses)
    var reportIsUpToDate: Bool {
        guard let r = aiService.result, !r.personalitySummary.isEmpty else { return false }
        return responseCount == r.respondentCount
    }

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()


            ScrollView {
                VStack(spacing: 20) {
                    header
                    step1Card
                    step2Card
                    step3Card
                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .refreshable { await feedbackService.refreshStatus() }
        }
        .alert("Analyse Fehler", isPresented: Binding(
            get: { aiService.error != nil },
            set: { if !$0 { aiService.error = nil } }
        )) {
            Button("OK") { aiService.error = nil }
        } message: {
            Text(aiService.error ?? "")
        }
        .sheet(isPresented: $showSelfAssessment) {
            FeedbackSurveyView(mode: .selfAssessment).environmentObject(auth).environmentObject(lang)
        }
        .sheet(isPresented: $showShareSheet) {
            if let link = feedbackService.feedbackLink {
                ShareSheet(items: [link.shareURL])
            }
        }
        .navigationDestination(isPresented: $showResults) {
            ResultsView().environmentObject(auth)
        }
        .task {
            // Load from Supabase if UserDefaults cache is empty (first install / cleared cache)
            if aiService.result == nil {
                await aiService.loadExistingResult()
            }
            // Try silent refresh if feedbackLink is already available
            await silentRefreshIfPossible()
        }
        // feedbackLink loads async after login — trigger refresh when it arrives
        .onChange(of: feedbackService.feedbackLink?.id) { _ in
            Task { await silentRefreshIfPossible() }
        }
    }

    private func silentRefreshIfPossible() async {
        guard aiService.result != nil, canAnalyze else { return }
        let assessment = auth.currentUser?.assessmentType?.rawValue ?? "General"
        let userId     = auth.currentUser?.id ?? ""
        let licenses   = auth.currentUser?.flightLicenses ?? []
        await aiService.analyzeFromBackend(
            assessmentType: assessment,
            userId: userId,
            flightLicenses: licenses,
            silent: true
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text(lang.t("Dein Assessment-Plan", "Your Assessment Plan"))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appPrimary)
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
            title: lang.t("Self-Assessment ausfüllen", "Complete Self-Assessment"),
            subtitle: selfDone
                ? lang.t("Abgeschlossen", "Completed")
                : lang.t("Beantworte denselben Fragebogen über dich selbst",
                          "Answer the same questionnaire about yourself"),
            done: selfDone,
            locked: false
        ) {
            if !selfDone {
                actionButton(lang.t("Jetzt starten", "Start now"),
                             icon: "pencil.and.list.clipboard", color: "4A9EF8") {
                    showSelfAssessment = true
                }
            }
        }
    }

    // MARK: - Step 2: Link teilen

    private var step2Card: some View {
        stepCard(
            number: 2,
            title: lang.t("Link an mindestens 5 Personen senden", "Send link to at least 5 people"),
            subtitle: feedbackService.feedbackLink == nil
                ? lang.t("Erstelle deinen persönlichen Feedback-Link", "Create your personal feedback link")
                : linkDone
                    ? lang.t("\(responseCount)/\(targetResponses) Rückmeldungen — Report freigeschaltet, mehr ist besser!",
                              "\(responseCount)/\(targetResponses) responses — report unlocked, more is better!")
                    : lang.t("\(responseCount) von \(minimumResponses) Minimum — \(minimumResponses - responseCount) fehlen noch",
                              "\(responseCount) of \(minimumResponses) minimum — \(minimumResponses - responseCount) missing"),
            done: linkDone,
            locked: false
        ) {
            if let link = feedbackService.feedbackLink {
                VStack(spacing: 10) {
                    // Response progress bar (always visible)
                    responseProgressBar

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
                    .background(Color.appCard)
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
                    isCreatingLink ? lang.t("Wird erstellt…", "Creating…") : lang.t("Link erstellen", "Create link"),
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
                    Text(lang.t("Erst Self-Assessment abschließen", "Complete self-assessment first"))
                        .font(.caption2)
                        .foregroundStyle(Color.appTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var responseProgressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule().fill(Color.appInputBG).frame(height: 8)
                    // Fill (0–12)
                    Capsule()
                        .fill(LinearGradient(
                            colors: responseCount >= minimumResponses
                                ? [Color(hex: "34C759"), Color(hex: "34C759")]
                                : [Color(hex: "4A9EF8"), Color(hex: "4A9EF8")],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * min(Double(responseCount) / Double(targetResponses), 1.0)), height: 8)
                        .animation(.spring(response: 0.5), value: responseCount)
                    // Milestone marker at 5/12
                    let milestoneX = geo.size.width * Double(minimumResponses) / Double(targetResponses)
                    Rectangle()
                        .fill(Color.appCard)
                        .frame(width: 2, height: 14)
                        .offset(x: milestoneX - 1, y: -3)
                }
            }
            .frame(height: 8)
            .padding(.top, 6)
            HStack {
                Text("0")
                Spacer()
                VStack(spacing: 1) {
                    Text(lang.t("5 min", "5 min"))
                        .foregroundStyle(responseCount >= 5 ? Color(hex: "34C759") : .white.opacity(0.5))
                    if responseCount >= 5 && responseCount < 12 {
                        Text(lang.t("✓ freigeschaltet", "✓ unlocked"))
                            .foregroundStyle(Color(hex: "34C759"))
                    }
                }
                Spacer()
                Text(lang.t("12 ideal", "12 ideal"))
                    .foregroundStyle(responseCount >= 12 ? Color(hex: "34C759") : .white.opacity(0.4))
            }
            .font(.caption2)
            .foregroundStyle(Color.appTertiary)
        }
    }

    // MARK: - Step 3: Analyse

    private var step3Card: some View {
        stepCard(
            number: 3,
            title: lang.t("KI-Analyse starten", "Start AI Analysis"),
            subtitle: {
                if reportIsUpToDate {
                    return lang.t("Report ist aktuell — keine neuen Antworten seit der letzten Analyse",
                                  "Report is up to date — no new responses since last analysis")
                } else if hasNewResponses {
                    let diff = responseCount - (aiService.result?.respondentCount ?? 0)
                    return lang.t("\(diff) neue Antwort\(diff == 1 ? "" : "en") seit dem letzten Report — Aktualisierung empfohlen",
                                  "\(diff) new response\(diff == 1 ? "" : "s") since last report — update recommended")
                } else if canAnalyze {
                    return lang.t("Alle Voraussetzungen erfüllt — Report kann erstellt werden",
                                  "All requirements met — report can be generated")
                } else {
                    return lang.t("Verfügbar sobald Self-Assessment und 5 Rückmeldungen vorliegen",
                                  "Available once self-assessment and 5 responses are complete")
                }
            }(),
            done: reportIsUpToDate,
            locked: !canAnalyze
        ) {
            if canAnalyze && !reportIsUpToDate {
                actionButton(
                    aiService.isAnalyzing
                        ? lang.t("Analysiere…", "Analyzing…")
                        : hasNewResponses
                            ? lang.t("Report aktualisieren", "Update report")
                            : lang.t("Report erstellen", "Generate report"),
                    icon: "sparkles",
                    color: "6B5EE4",
                    gradient: true
                ) {
                    Task {
                        let assessment = auth.currentUser?.assessmentType?.rawValue ?? "General"
                        let userId     = auth.currentUser?.id ?? ""
                        let licenses   = auth.currentUser?.flightLicenses ?? []
                        await aiService.analyzeFromBackend(
                            assessmentType: assessment,
                            userId: userId,
                            flightLicenses: licenses
                        )
                        if aiService.result != nil {
                            showResults = true
                        } else if let err = aiService.error {
                            print("❌ Analysis error: \(err)")
                        }
                    }
                }
                .disabled(aiService.isAnalyzing)
            }
            if aiService.result != nil {
                actionButton(lang.t("Report anzeigen", "View report"), icon: "doc.text.fill", color: "34C759") {
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
                        .fill(done ? Color(hex: "34C759") : locked ? Color.appCard : Color(hex: "4A9EF8").opacity(0.2))
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
        .background(done ? Color(hex: "34C759").opacity(0.07) : Color.appCard)
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
                .foregroundStyle(Color.appPrimary)
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
                    .foregroundStyle(Color.appSecondary)
            }
        }
        .frame(maxWidth: .infinity)
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

}
