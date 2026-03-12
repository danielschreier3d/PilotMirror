import Foundation
import AuthenticationServices

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Backend DTO for the `users` table
// ─────────────────────────────────────────────────────────────────────────────
private struct UserRecord: Codable {
    let id:             String
    let email:          String
    let name:           String
    let assessmentType: String?
    // SBDecoder .convertFromSnakeCase: assessment_type → assessmentType ✓
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AuthService
// ─────────────────────────────────────────────────────────────────────────────
@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var currentUser:    User?
    @Published var isAuthenticated = false
    @Published var isLoading       = false
    @Published var error:          String?

    private let sb = SupabaseClient.shared

    private override init() {
        super.init()
        Task { await restoreSession() }
    }

    // MARK: – Session restore

    func restoreSession() async {
        guard sb.isAuthenticated, let uid = sb.userId else { return }
        do {
            if let record: UserRecord = try await sb.selectFirst(
                from: "users", filters: ["id": "eq.\(uid)"]
            ) {
                currentUser     = map(record)
                isAuthenticated = true
            } else {
                sb.signOut()   // token valid but user row missing
            }
        } catch {
            sb.signOut()       // network error or expired token
        }
    }

    // MARK: – Apple Sign-In

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true; defer { isLoading = false }
        error = nil
        switch result {
        case .failure(let e):
            self.error = e.localizedDescription
        case .success(let auth):
            guard
                let cred      = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = cred.identityToken,
                let idToken   = String(data: tokenData, encoding: .utf8)
            else { self.error = "Invalid Apple credential"; return }

            let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            do {
                let r = try await sb.signInApple(idToken: idToken)
                await createOrFetchUser(id: r.user.id,
                                        email: r.user.email ?? "",
                                        name: name.isEmpty ? "Pilot" : name)
            } catch { self.error = error.localizedDescription }
        }
    }

    // MARK: – Email auth

    func signUp(name: String, email: String, password: String) async {
        isLoading = true; defer { isLoading = false }; error = nil
        do {
            let r = try await sb.signUpEmail(email: email, password: password)
            await createOrFetchUser(id: r.user.id, email: email,
                                    name: name.isEmpty ? "Pilot" : name)
        } catch { self.error = error.localizedDescription }
    }

    func signIn(email: String, password: String) async {
        isLoading = true; defer { isLoading = false }; error = nil
        do {
            let r = try await sb.signInEmail(email: email, password: password)
            await createOrFetchUser(id: r.user.id, email: email, name: "")
        } catch { self.error = error.localizedDescription }
    }

    // MARK: – Sign out

    func signOut() {
        sb.signOut()
        currentUser     = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "pm_session_id")
    }

    // MARK: – Assessment type

    func updateAssessmentType(_ type: User.AssessmentType) {
        guard let user = currentUser else { return }
        currentUser = User(id: user.id, name: user.name, email: user.email, assessmentType: type)
        Task {
            try? await sb.update(
                table: "users",
                filters: ["id": "eq.\(user.id)"],
                body: ["assessment_type": type.rawValue]
            )
        }
    }

    // MARK: – Private

    private func createOrFetchUser(id: String, email: String, name: String) async {
        if let record: UserRecord = try? await sb.selectFirst(
            from: "users", filters: ["id": "eq.\(id)"]
        ) {
            currentUser = map(record); isAuthenticated = true; return
        }
        let record = UserRecord(id: id, email: email,
                                name: name.isEmpty ? "Pilot" : name,
                                assessmentType: nil)
        try? await sb.insert(into: "users", value: record)
        currentUser = map(record); isAuthenticated = true
    }

    private func map(_ r: UserRecord) -> User {
        User(id: r.id, name: r.name, email: r.email,
             assessmentType: r.assessmentType.flatMap { User.AssessmentType(rawValue: $0) })
    }
}
