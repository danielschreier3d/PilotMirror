import SwiftUI

struct CreateFeedbackLinkView: View {
    @EnvironmentObject var auth: AuthService
    @ObservedObject var feedbackService = FeedbackService.shared
    @State private var isCreating = false
    @State private var showShareSheet = false
    @State private var copied = false

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color(hex: "4A9EF8"))

                        Text("Get Your Feedback Link")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appPrimary)

                        Text("Share it with 5–12 people who know you well.\nTheir responses will be anonymous.")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Recommended people
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommended")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appSecondary)
                            .textCase(.uppercase)
                            .tracking(1)

                        ForEach([
                            ("Friends", "person.2.fill", "4A9EF8"),
                            ("Colleagues", "briefcase.fill", "34C759"),
                            ("Flight Instructors", "airplane", "FF9F0A"),
                            ("Family members", "house.fill", "FF6B6B"),
                        ], id: \.0) { item in
                            HStack(spacing: 12) {
                                Image(systemName: item.1)
                                    .foregroundStyle(Color(hex: item.2))
                                    .frame(width: 28)
                                Text(item.0)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Link card or generate button
                    if let link = feedbackService.feedbackLink {
                        linkCard(link)
                    } else {
                        generateButton
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    private var generateButton: some View {
        Button {
            Task {
                isCreating = true
                let candidateId = auth.currentUser?.id ?? UUID().uuidString
                _ = try? await feedbackService.createFeedbackLink(candidateId: candidateId)
                isCreating = false
            }
        } label: {
            Group {
                if isCreating {
                    ProgressView().tint(.white)
                } else {
                    Label("Generate My Link", systemImage: "wand.and.stars")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(hex: "4A9EF8"))
            .foregroundStyle(Color.appPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .disabled(isCreating)
    }

    private func linkCard(_ link: FeedbackLink) -> some View {
        VStack(spacing: 16) {
            // URL display
            HStack {
                Text(link.shareURLString)
                    .font(.system(.caption, design: .monospaced))
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
            .padding(14)
            .background(Color.appInputBG)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Share buttons
            VStack(spacing: 10) {
                shareButton("Share via WhatsApp", icon: "message.fill", color: "34C759") {
                    openWhatsApp(link.shareURLString)
                }
                shareButton("Share via iMessage", icon: "message.fill", color: "4A9EF8") {
                    openMessages(link.shareURLString)
                }
                shareButton("Share via Email", icon: "envelope.fill", color: "FF9F0A") {
                    openMail(link.shareURLString)
                }
                shareButton("Share…", icon: "square.and.arrow.up", color: "8E8E93") {
                    showShareSheet = true
                }
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [link.shareURL])
        }
    }

    private func shareButton(_ title: String, icon: String, color: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color(hex: color))
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func openWhatsApp(_ url: String) {
        let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        let msg = "Hey! I'd appreciate your anonymous feedback for my pilot assessment:\n\(encoded)"
        let wa = "whatsapp://send?text=\(msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let u = URL(string: wa) { UIApplication.shared.open(u) }
    }

    private func openMessages(_ url: String) {
        let sms = "sms:&body=Hey! Please give me anonymous feedback for my pilot assessment: \(url)"
        if let u = URL(string: sms.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sms) {
            UIApplication.shared.open(u)
        }
    }

    private func openMail(_ url: String) {
        let body = "Hi,\n\nI'm preparing for my pilot assessment and would really value your feedback.\nIt's anonymous and takes less than 3 minutes:\n\(url)\n\nThank you!"
        let mail = "mailto:?subject=Feedback%20Request%20–%20PilotMirror&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let u = URL(string: mail) { UIApplication.shared.open(u) }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    CreateFeedbackLinkView()
        .environmentObject(AuthService.shared)
}
