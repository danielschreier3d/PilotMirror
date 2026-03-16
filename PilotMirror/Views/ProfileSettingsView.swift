import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.dismiss)    private var dismiss
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var lang: LanguageService
    @AppStorage("pm_appearance") private var appearanceRaw = 2

    // Password change
    @State private var newPassword        = ""
    @State private var confirmPassword    = ""
    @State private var isUpdatingPassword = false
    @State private var passwordMessage:   String?
    @State private var passwordSuccess    = false

    // Destructive actions
    @State private var showResetConfirm  = false
    @State private var showDeleteConfirm = false
    @State private var isResetting       = false
    @State private var isDeleting        = false
    @State private var actionError:      String?

    private let bg     = Color.appBG
    private let card   = Color.appCard
    private let accent = Color(hex: "4A9EF8")

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    header
                    userCard
                    languageSection
                    appearanceSection
                    passwordSection
                    accountActions
                    signOutButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .confirmationDialog(
            lang.isGerman ? "Alle Umfragedaten löschen?" : "Delete all survey data?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(lang.isGerman ? "Zurücksetzen" : "Reset", role: .destructive) {
                Task {
                    isResetting = true
                    await auth.resetSurveyData()
                    isResetting = false
                }
            }
            Button(lang.isGerman ? "Abbrechen" : "Cancel", role: .cancel) {}
        } message: {
            Text(lang.isGerman
                 ? "Selbsteinschätzung, Feedback-Link und KI-Analyse werden unwiderruflich gelöscht."
                 : "Self-assessment, feedback link and AI analysis will be permanently deleted.")
        }
        .confirmationDialog(
            lang.isGerman ? "Account unwiderruflich löschen?" : "Permanently delete account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(lang.isGerman ? "Account löschen" : "Delete Account", role: .destructive) {
                Task {
                    isDeleting = true
                    await auth.deleteAccount()
                    isDeleting = false
                    dismiss()
                }
            }
            Button(lang.isGerman ? "Abbrechen" : "Cancel", role: .cancel) {}
        } message: {
            Text(lang.isGerman
                 ? "Dein Account und alle gespeicherten Daten werden dauerhaft entfernt."
                 : "Your account and all stored data will be permanently removed.")
        }
    }

    // MARK: – Header

    private var header: some View {
        HStack {
            Text(lang.isGerman ? "Profil & Einstellungen" : "Profile & Settings")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.appPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.appTertiary)
            }
        }
        .padding(.top, 24)
    }

    // MARK: – User info card

    private var userCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 6) {
                Text(auth.currentUser?.name ?? "—")
                    .font(.headline)
                    .foregroundStyle(Color.appPrimary)
                Text(auth.currentUser?.email ?? "—")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondary)
                // Assessment type chip
                if let at = auth.currentUser?.assessmentType {
                    HStack(spacing: 4) {
                        Image(systemName: at.icon)
                            .font(.caption2)
                        Text(at.rawValue)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(accent.opacity(0.15))
                    .clipShape(Capsule())
                }
                // Flight licenses (exclude .none)
                let licenses = auth.currentUser?.flightLicenses?.filter { $0 != .none } ?? []
                if !licenses.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(licenses, id: \.self) { lic in
                            HStack(spacing: 3) {
                                Image(systemName: lic.icon).font(.caption2)
                                Text(lang.isGerman ? lic.rawValue : lic.rawValue)
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundStyle(Color(hex: "34C759"))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color(hex: "34C759").opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(18)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appBorder, lineWidth: 1))
    }

    // MARK: – Language section

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(lang.isGerman ? "Sprache" : "Language")
            HStack(spacing: 0) {
                ForEach([(true, "Deutsch", "DE"), (false, "English", "EN")], id: \.0) { isDE, label, short in
                    Button {
                        withAnimation { lang.isGerman = isDE }
                    } label: {
                        VStack(spacing: 2) {
                            Text(short)
                                .font(.subheadline.weight(.bold))
                            Text(label)
                                .font(.caption2)
                        }
                        .foregroundStyle(lang.isGerman == isDE ? .white : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(lang.isGerman == isDE ? accent : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.appInputBG)
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .padding(18)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appBorder, lineWidth: 1))
    }

    // MARK: – Appearance section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(lang.isGerman ? "Darstellung" : "Appearance")
            HStack(spacing: 0) {
                ForEach([
                    (1, "sun.max.fill",   lang.isGerman ? "Hell"       : "Light"),
                    (2, "moon.stars.fill", lang.isGerman ? "Dunkel"     : "Dark"),
                    (0, "circle.lefthalf.filled", lang.isGerman ? "System" : "System"),
                ], id: \.0) { raw, icon, label in
                    Button { withAnimation { appearanceRaw = raw } } label: {
                        VStack(spacing: 4) {
                            Image(systemName: icon).font(.system(size: 16))
                            Text(label).font(.caption2)
                        }
                        .foregroundStyle(appearanceRaw == raw ? .white : Color.appTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(appearanceRaw == raw ? accent : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.appInputBG)
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .padding(18)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appBorder, lineWidth: 1))
    }

    // MARK: – Password section

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(lang.isGerman ? "Passwort ändern" : "Change Password")

            SecureField(lang.isGerman ? "Neues Passwort" : "New Password", text: $newPassword)
                .textContentType(.newPassword)
                .foregroundStyle(Color.appPrimary)
                .padding(14)
                .background(Color.appInputBG)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))

            SecureField(lang.isGerman ? "Bestätigen" : "Confirm", text: $confirmPassword)
                .textContentType(.newPassword)
                .foregroundStyle(Color.appPrimary)
                .padding(14)
                .background(Color.appInputBG)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))

            if let msg = passwordMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(passwordSuccess ? Color(hex: "34C759") : Color(hex: "FF3B30"))
            }

            Button {
                Task { await updatePassword() }
            } label: {
                HStack {
                    if isUpdatingPassword {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    }
                    Text(lang.isGerman ? "Passwort aktualisieren" : "Update Password")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(newPassword.isEmpty || isUpdatingPassword)
        }
        .padding(18)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appBorder, lineWidth: 1))
    }

    // MARK: – Account actions

    private var accountActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(lang.isGerman ? "Kontoverwaltung" : "Account Management")

            if let err = actionError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(Color(hex: "FF3B30"))
            }

            // Reset survey data
            Button { showResetConfirm = true } label: {
                HStack {
                    if isResetting { ProgressView().tint(Color(hex: "FF9500")).scaleEffect(0.8) }
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(Color(hex: "FF9500"))
                    Text(lang.isGerman ? "Umfragedaten zurücksetzen" : "Reset Survey Data")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(hex: "FF9500"))
                    Spacer()
                }
                .padding(14)
                .background(Color(hex: "FF9500").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "FF9500").opacity(0.3), lineWidth: 1))
            }
            .disabled(isResetting || isDeleting)

            // Delete account
            Button { showDeleteConfirm = true } label: {
                HStack {
                    if isDeleting { ProgressView().tint(Color(hex: "FF3B30")).scaleEffect(0.8) }
                    Image(systemName: "trash")
                        .foregroundStyle(Color(hex: "FF3B30"))
                    Text(lang.isGerman ? "Account löschen" : "Delete Account")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(hex: "FF3B30"))
                    Spacer()
                }
                .padding(14)
                .background(Color(hex: "FF3B30").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "FF3B30").opacity(0.3), lineWidth: 1))
            }
            .disabled(isResetting || isDeleting)
        }
        .padding(18)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appBorder, lineWidth: 1))
    }

    // MARK: – Sign out

    private var signOutButton: some View {
        Button {
            auth.signOut()
            dismiss()
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text(lang.isGerman ? "Abmelden" : "Sign Out")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.appSecondary)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Color.appInputBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.appBorder, lineWidth: 1))
        }
    }

    // MARK: – Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appTertiary)
            .textCase(.uppercase)
            .kerning(0.8)
    }

    private func updatePassword() async {
        passwordMessage = nil
        guard newPassword == confirmPassword else {
            passwordSuccess = false
            passwordMessage = lang.isGerman
                ? "Passwörter stimmen nicht überein."
                : "Passwords do not match."
            return
        }
        guard newPassword.count >= 8 else {
            passwordSuccess = false
            passwordMessage = lang.isGerman
                ? "Mindestens 8 Zeichen erforderlich."
                : "At least 8 characters required."
            return
        }
        isUpdatingPassword = true
        defer { isUpdatingPassword = false }
        do {
            try await auth.changePassword(newPassword: newPassword)
            newPassword     = ""
            confirmPassword = ""
            passwordSuccess = true
            passwordMessage = lang.isGerman
                ? "Passwort erfolgreich geändert."
                : "Password updated successfully."
        } catch {
            passwordSuccess = false
            passwordMessage = error.localizedDescription
        }
    }
}
