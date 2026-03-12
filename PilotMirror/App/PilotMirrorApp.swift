import SwiftUI

@main
struct PilotMirrorApp: App {
    @StateObject private var auth     = AuthService.shared
    @StateObject private var lang     = LanguageService.shared
    @StateObject private var deepLink = DeepLinkHandler.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(lang)
                .environmentObject(deepLink)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    DeepLinkHandler.shared.handle(url)
                }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RootView
// ─────────────────────────────────────────────────────────────────────────────
struct RootView: View {
    @EnvironmentObject var auth:     AuthService
    @EnvironmentObject var deepLink: DeepLinkHandler
    @State private var selectedAssessment: User.AssessmentType?

    var body: some View {
        // Deep link: email confirmation callback
        if let tokens = deepLink.pendingAuthTokens {
            Color.clear.task {
                try? await SupabaseClient.shared.applyAuthTokens(
                    access: tokens.access, refresh: tokens.refresh)
                await auth.restoreSession()
                deepLink.clearPendingAuth()
            }
        }
        // Deep link: open respondent survey without requiring auth
        if let token = deepLink.pendingFeedbackToken {
            FeedbackSurveyView(mode: .respondent(token: token))
                .environmentObject(LanguageService.shared)
                .environmentObject(auth)
                .onDisappear { deepLink.clearPendingToken() }
        } else if !auth.isAuthenticated {
            OnboardingView()
        } else if auth.currentUser?.assessmentType == nil {
            NavigationStack {
                AssessmentSelectView(selectedAssessment: $selectedAssessment)
            }
        } else {
            MainTabView()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MainTabView
// ─────────────────────────────────────────────────────────────────────────────
struct MainTabView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var lang: LanguageService
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                FeedbackStatusView()
                    .navigationTitle("Dashboard")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            HStack(spacing: 12) {
                                // Language toggle
                                Button {
                                    withAnimation { lang.isGerman.toggle() }
                                } label: {
                                    Text(lang.isGerman ? "EN" : "DE")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Color(hex: "4A9EF8").opacity(0.25))
                                        .clipShape(Capsule())
                                }
                                // Sign out
                                Button {
                                    auth.signOut()
                                } label: {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundStyle(Color(hex: "4A9EF8"))
                                }
                            }
                        }
                    }
            }
            .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
            .tag(0)

            NavigationStack {
                AssessmentAdviceView()
            }
            .tabItem { Label(lang.isGerman ? "Tipps" : "Tips", systemImage: "lightbulb.fill") }
            .tag(1)
        }
        .tint(Color(hex: "4A9EF8"))
        .onAppear {
            if let userId = auth.currentUser?.id {
                Task { await FeedbackService.shared.loadForUser(userId: userId) }
            }
        }
    }
}
