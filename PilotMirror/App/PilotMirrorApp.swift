import SwiftUI

@main
struct PilotMirrorApp: App {
    @StateObject private var auth     = AuthService.shared
    @StateObject private var lang     = LanguageService.shared
    @StateObject private var deepLink = DeepLinkHandler.shared
    @AppStorage("pm_appearance") private var appearanceRaw = 2  // default: dark

    private var preferredScheme: ColorScheme? {
        switch appearanceRaw {
        case 1:  return .light
        case 2:  return .dark
        default: return nil  // follow system
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(lang)
                .environmentObject(deepLink)
                .preferredColorScheme(preferredScheme)
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
    @EnvironmentObject var lang:     LanguageService
    @EnvironmentObject var deepLink: DeepLinkHandler
    @State private var selectedAssessment: User.AssessmentType?
    @State private var flightLicenses: [User.FlightLicense]?
    @State private var privacyAccepted = UserDefaults.standard.bool(forKey: "pm_privacy_accepted")

    // Splash state — hide after BOTH the animation AND session restore are done
    @State private var showSplash      = true
    @State private var splashAnimDone  = false

    var body: some View {
        ZStack {
            // ── Main content (always rendered beneath splash) ──────────
            mainContent

            // ── Splash overlay ─────────────────────────────────────────
            if showSplash {
                SplashView {
                    splashAnimDone = true
                    tryDismissSplash()
                }
                .zIndex(1)
                .transition(.opacity)
            }
        }
        .onChange(of: auth.isRestoring) { _, restoring in
            if !restoring { tryDismissSplash() }
        }
    }

    private func tryDismissSplash() {
        guard splashAnimDone && !auth.isRestoring else { return }
        withAnimation(.easeInOut(duration: 0.9)) {
            showSplash = false
        }
    }

    @ViewBuilder
    private var mainContent: some View {
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
        } else if !privacyAccepted {
            PrivacyConsentView { privacyAccepted = true }
                .environmentObject(lang)
        } else if auth.currentUser?.assessmentType == nil {
            NavigationStack {
                AssessmentSelectView(selectedAssessment: $selectedAssessment)
            }
        } else if auth.currentUser?.flightLicenses == nil {
            NavigationStack {
                FlightLicenseSelectView(flightLicenses: $flightLicenses)
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
    @State private var selectedTab        = 0
    @State private var showProfileSettings = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                FeedbackStatusView()
                    .navigationTitle("Dashboard")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showProfileSettings = true
                            } label: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(Color(hex: "4A9EF8"))
                            }
                        }
                    }
                    .sheet(isPresented: $showProfileSettings) {
                        ProfileSettingsView()
                            .environmentObject(auth)
                            .environmentObject(lang)
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
