import SwiftUI

@main
struct PilotMirrorApp: App {
    @StateObject private var auth = AuthService.shared
    @StateObject private var lang = LanguageService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(lang)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthService
    @State private var selectedAssessment: User.AssessmentType?

    var body: some View {
        if !auth.isAuthenticated {
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
            FeedbackService.shared.loadSavedLink()
        }
    }
}
