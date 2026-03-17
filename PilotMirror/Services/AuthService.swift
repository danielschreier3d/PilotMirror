import Foundation
import AuthenticationServices

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Backend DTO for the `users` table
// ─────────────────────────────────────────────────────────────────────────────
private struct UserRecord: Codable {
    let id:             String
    let email:          String
    let fullName:       String    // encodes to full_name
    let assessmentType: String?   // encodes to assessment_type
    let flightLicenses: [String]? // encodes to flight_licenses
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AuthService
// ─────────────────────────────────────────────────────────────────────────────
@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var currentUser:              User?
    @Published var isAuthenticated           = false
    @Published var isRestoring               = true   // true until first restoreSession() completes
    @Published var isLoading                 = false
    @Published var error:                    String?
    @Published var pendingEmailConfirmation  = false
    @Published var loginLockedUntil:         Date?

    private var loginFailedAttempts = 0
    private let maxLoginAttempts    = 5
    private let lockoutDuration: TimeInterval = 5 * 60

    private let sb = SupabaseClient.shared

    private override init() {
        super.init()
        Task { await restoreSession() }
    }

    // MARK: – Session restore

    func restoreSession() async {
        defer { isRestoring = false }
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

    // MARK: – Email auth

    func signUp(name: String, email: String, password: String, inviteCode: String) async {
        isLoading = true; defer { isLoading = false }; error = nil
        do {
            let valid = try await sb.validateInviteCode(code: inviteCode, email: email)
            guard valid else {
                self.error = "Invalid invite code or email not authorised."
                return
            }
            let r = try await sb.signUpEmail(email: email, password: password)
            try? await sb.redeemInviteCode(code: inviteCode)
            if r.accessToken != nil {
                await createOrFetchUser(id: r.user?.id ?? sb.userId ?? "", email: email,
                                        name: name.isEmpty ? "Pilot" : name)
            } else {
                pendingEmailConfirmation = true
            }
        } catch { self.error = error.localizedDescription }
    }

    func signIn(email: String, password: String) async {
        if let locked = loginLockedUntil, locked > Date() { return }
        isLoading = true; defer { isLoading = false }; error = nil
        do {
            let r = try await sb.signInEmail(email: email, password: password)
            loginFailedAttempts = 0
            loginLockedUntil    = nil
            await createOrFetchUser(id: r.user?.id ?? sb.userId ?? "", email: email, name: "")
        } catch {
            loginFailedAttempts += 1
            if loginFailedAttempts >= maxLoginAttempts {
                loginLockedUntil = Date().addingTimeInterval(lockoutDuration)
                self.error = nil   // OnboardingView reads loginLockedUntil directly
            } else {
                let remaining = maxLoginAttempts - loginFailedAttempts
                self.error = "Incorrect email or password. \(remaining) attempt\(remaining == 1 ? "" : "s") remaining."
            }
        }
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
        currentUser = User(id: user.id, name: user.name, email: user.email,
                           assessmentType: type, flightLicenses: user.flightLicenses)
        Task {
            try? await sb.update(
                table: "users",
                filters: ["id": "eq.\(user.id)"],
                body: ["assessment_type": type.rawValue]
            )
        }
    }

    // MARK: – Password reset (unauthenticated)

    func sendPasswordReset(email: String) async throws {
        try await sb.sendPasswordReset(email: email)
    }

    // MARK: – Password change

    func changePassword(newPassword: String) async throws {
        isLoading = true; defer { isLoading = false }
        try await sb.updatePassword(newPassword)
    }

    // MARK: – Reset survey data

    func resetSurveyData() async {
        guard let uid = sb.userId else { return }
        let sessionId = UserDefaults.standard.string(forKey: "pm_session_id")
        if let sid = sessionId {
            try? await sb.delete(from: "self_responses",
                                 filters: ["session_id": "eq.\(sid)"])
            try? await sb.delete(from: "feedback_links",
                                 filters: ["session_id": "eq.\(sid)"])
            try? await sb.delete(from: "assessment_sessions",
                                 filters: ["candidate_id": "eq.\(uid)"])
        }
        let keys = ["pm_session_id", "pm_feedback_link", "pm_self_responses",
                    "pm_analysis_result_v1", "pm_interview_questions_v1"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        SurveyService.shared.clearLocalCache()
        FeedbackService.shared.feedbackLink = nil
        FeedbackService.shared.respondents  = []
        AIAnalysisService.shared.result     = nil
        AIAnalysisService.shared.cachedInterviewQuestions = []
    }

    // MARK: – Delete account

    func deleteAccount() async {
        guard let uid = sb.userId else { return }
        await resetSurveyData()
        try? await sb.delete(from: "users", filters: ["id": "eq.\(uid)"])
        signOut()
    }

    func updateFlightLicenses(_ licenses: [User.FlightLicense]) {
        guard let user = currentUser else { return }
        currentUser = User(id: user.id, name: user.name, email: user.email,
                           assessmentType: user.assessmentType, flightLicenses: licenses)
        Task {
            try? await sb.update(
                table: "users",
                filters: ["id": "eq.\(user.id)"],
                body: ["flight_licenses": licenses.map(\.rawValue)]
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
                                assessmentType: nil, flightLicenses: nil)
        try? await sb.insert(into: "users", value: record)
        currentUser = map(record); isAuthenticated = true
    }

    private func map(_ r: UserRecord) -> User {
        let licenses = r.flightLicenses?.compactMap { User.FlightLicense(rawValue: $0) }
        return User(id: r.id, name: r.fullName, email: r.email,
                    assessmentType: r.assessmentType.flatMap { User.AssessmentType(rawValue: $0) },
                    flightLicenses: licenses)
    }
}
