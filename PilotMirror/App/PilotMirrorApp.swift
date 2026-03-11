import SwiftUI

@main
struct PilotMirrorApp: App {
    @StateObject private var auth = AuthService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
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
                            Button {
                                auth.signOut()
                            } label: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(Color(hex: "4A9EF8"))
                            }
                        }
                    }
            }
            .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
            .tag(0)

            NavigationStack {
                CreateFeedbackLinkView()
                    .navigationTitle("Share Link")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .tabItem { Label("Share", systemImage: "square.and.arrow.up.fill") }
            .tag(1)

            NavigationStack {
                AssessmentAdviceView()
            }
            .tabItem { Label("Advice", systemImage: "lightbulb.fill") }
            .tag(2)
        }
        .tint(Color(hex: "4A9EF8"))
        .onAppear {
            FeedbackService.shared.loadSavedLink()
        }
    }
}
