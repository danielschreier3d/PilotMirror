import Foundation
import AuthenticationServices

@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?

    private override init() {
        super.init()
        restoreSession()
    }

    private func restoreSession() {
        // TODO: Replace with Supabase session restore
        // supabase.auth.session
        if let data = UserDefaults.standard.data(forKey: "pm_user"),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            currentUser = user
            isAuthenticated = true
        }
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        defer { isLoading = false }
        switch result {
        case .failure(let e):
            error = e.localizedDescription
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            // TODO: supabase.auth.signInWithIdToken(provider: .apple, idToken: ...)
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            let user = User(id: credential.user, name: name, email: credential.email ?? "", assessmentType: nil)
            await persist(user)
        }
    }

    // MARK: - Email

    func signUp(name: String, email: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        // TODO: supabase.auth.signUp(email: email, password: password)
        // Then insert into users table
        let user = User(id: UUID().uuidString, name: name, email: email, assessmentType: nil)
        await persist(user)
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        // TODO: supabase.auth.signIn(email: email, password: password)
        let user = User(id: UUID().uuidString, name: "", email: email, assessmentType: nil)
        await persist(user)
    }

    func signOut() {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "pm_user")
        // TODO: try? await supabase.auth.signOut()
    }

    func updateAssessmentType(_ type: User.AssessmentType) {
        guard var user = currentUser else { return }
        user = User(id: user.id, name: user.name, email: user.email, assessmentType: type)
        currentUser = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "pm_user")
        }
        // TODO: supabase.from("users").update(["assessment_type": type.rawValue]).eq("id", user.id)
    }

    private func persist(_ user: User) async {
        currentUser = user
        isAuthenticated = true
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "pm_user")
        }
    }
}
