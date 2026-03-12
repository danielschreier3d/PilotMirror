import Foundation
import AuthenticationServices
import UIKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Backend DTO for the `users` table
// ─────────────────────────────────────────────────────────────────────────────
private struct UserRecord: Codable {
    let id:             String
    let email:          String
    let fullName:       String   // encodes to full_name via convertToSnakeCase
    let assessmentType: String?  // encodes to assessment_type ✓
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AuthService
// ─────────────────────────────────────────────────────────────────────────────
@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var currentUser:              User?
    @Published var isAuthenticated           = false
    @Published var isLoading                 = false
    @Published var error:                    String?
    @Published var pendingEmailConfirmation  = false

    private let sb = SupabaseClient.shared
    private var googleSession: ASWebAuthenticationSession?

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
                await createOrFetchUser(id: r.user?.id ?? sb.userId ?? "",
                                        email: r.user?.email ?? "",
                                        name: name.isEmpty ? "Pilot" : name)
            } catch { self.error = error.localizedDescription }
        }
    }

    // MARK: – Google Sign-In (via Supabase OAuth)

    func signInWithGoogle() async {
        isLoading = true; defer { isLoading = false }
        error = nil

        let urlString = "\(SupabaseConfig.projectURL)/auth/v1/authorize?provider=google&redirect_to=pilotmirror://auth/callback"
        guard let url = URL(string: urlString) else { return }

        do {
            let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: "pilotmirror"
                ) { url, err in
                    if let err = err { cont.resume(throwing: err) }
                    else if let url = url { cont.resume(returning: url) }
                    else { cont.resume(throwing: URLError(.badURL)) }
                }
                session.presentationContextProvider = AuthWindowProvider.shared
                session.prefersEphemeralWebBrowserSession = false
                googleSession = session
                session.start()
            }

            // Re-use existing deep link parsing
            DeepLinkHandler.shared.handle(callbackURL)
            if let tokens = DeepLinkHandler.shared.pendingAuthTokens {
                try await sb.applyAuthTokens(access: tokens.access, refresh: tokens.refresh)
                await restoreSession()
                DeepLinkHandler.shared.clearPendingAuth()
            }
        } catch {
            let asError = error as? ASWebAuthenticationSessionError
            if asError?.code != .canceledLogin {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: – Email auth

    func signUp(name: String, email: String, password: String) async {
        isLoading = true; defer { isLoading = false }; error = nil
        do {
            let r = try await sb.signUpEmail(email: email, password: password)
            if r.accessToken != nil {
                await createOrFetchUser(id: r.user?.id ?? sb.userId ?? "", email: email,
                                        name: name.isEmpty ? "Pilot" : name)
            } else {
                pendingEmailConfirmation = true
            }
        } catch { self.error = error.localizedDescription }
    }

    func signIn(email: String, password: String) async {
        isLoading = true; defer { isLoading = false }; error = nil
        do {
            let r = try await sb.signInEmail(email: email, password: password)
            await createOrFetchUser(id: r.user?.id ?? sb.userId ?? "", email: email, name: "")
        } catch { self.error = error.localizedDescription }
    }

    // MARK: – Sign out

    func signOut() {
        sb.signOut()
        currentUser     = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "pm_session_id")
        UserDefaults.standard.removeObject(forKey: "pm_feedback_link")
        SurveyService.shared.clearLocalCache()
        FeedbackService.shared.feedbackLink = nil
        AIAnalysisService.shared.result     = nil
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
        // Clear stale session caches — re-fetch for this specific user
        UserDefaults.standard.removeObject(forKey: "pm_session_id")
        UserDefaults.standard.removeObject(forKey: "pm_feedback_link")
        SurveyService.shared.clearLocalCache()
        FeedbackService.shared.feedbackLink = nil
        AIAnalysisService.shared.result = nil

        if let record: UserRecord = try? await sb.selectFirst(
            from: "users", filters: ["id": "eq.\(id)"]
        ) {
            currentUser = map(record); isAuthenticated = true; return
        }
        let record = UserRecord(id: id, email: email,
                                fullName: name.isEmpty ? "Pilot" : name,
                                assessmentType: nil)
        try? await sb.insert(into: "users", value: record)
        currentUser = map(record); isAuthenticated = true
    }

    private func map(_ r: UserRecord) -> User {
        User(id: r.id, name: r.fullName, email: r.email,
             assessmentType: r.assessmentType.flatMap { User.AssessmentType(rawValue: $0) })
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Presentation context for ASWebAuthenticationSession
// ─────────────────────────────────────────────────────────────────────────────
private final class AuthWindowProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthWindowProvider()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
