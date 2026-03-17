import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var auth: AuthService
    @State private var isSignUp           = true
    @State private var name               = ""
    @State private var email              = ""
    @State private var password           = ""
    @State private var inviteCode         = ""
    @State private var showForgotPassword = false
    @State private var resetEmail         = ""
    @State private var isResetting        = false
    @State private var resetMessage:      String?
    @State private var resetSuccess       = false
    @State private var now                = Date()

    private var isLocked: Bool {
        guard let until = auth.loginLockedUntil else { return false }
        return until > now
    }
    private var lockoutCountdown: String {
        guard let until = auth.loginLockedUntil else { return "" }
        let secs = max(0, Int(until.timeIntervalSince(now)))
        let m = secs / 60; let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        ZStack {
            Color.appBG
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Logo
                    VStack(spacing: 12) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color(hex: "4A9EF8"))
                            .shadow(color: Color(hex: "4A9EF8").opacity(0.4), radius: 20)

                        Text("PilotMirror")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appPrimary)

                        Text("Understand how others perceive you\nbefore your pilot assessment.")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                    // Tab picker
                    Picker("Mode", selection: $isSignUp) {
                        Text("Create Account").tag(true)
                        Text("Sign In").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)

                    // Fields
                    VStack(spacing: 14) {
                        if isSignUp {
                            authField("Full Name", text: $name, icon: "person.fill",
                                      keyboard: .default, capitalize: .words)
                        }
                        authField("Email", text: $email, icon: "envelope.fill",
                                  keyboard: .emailAddress, capitalize: .never)
                        authField("Password", text: $password, icon: "lock.fill", isSecure: true)
                        if isSignUp {
                            authField("Invite Code", text: $inviteCode,
                                      icon: "ticket.fill", capitalize: .characters)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // Error / Lockout
                    if isLocked {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                            Text("Too many failed attempts. Try again in \(lockoutCountdown).")
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(Color(hex: "FF6B6B"))
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    } else if let err = auth.error {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color(hex: "FF6B6B"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                    // Action button
                    Button {
                        Task {
                            if isSignUp {
                                await auth.signUp(name: name, email: email, password: password,
                                                  inviteCode: inviteCode)
                            } else {
                                await auth.signIn(email: email, password: password)
                            }
                        }
                    } label: {
                        Group {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "4A9EF8"))
                        .foregroundStyle(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .disabled(auth.isLoading || email.isEmpty || password.isEmpty ||
                              (isSignUp && (name.isEmpty || inviteCode.isEmpty)) ||
                              (!isSignUp && isLocked))

                    // Forgot password (Sign In only)
                    if !isSignUp {
                        Button { showForgotPassword = true } label: {
                            Text("Forgot password?")
                                .font(.footnote)
                                .foregroundStyle(Color(hex: "4A9EF8").opacity(0.8))
                        }
                        .padding(.top, 4)
                    }

                    Text("By continuing you agree to our Terms & Privacy Policy.")
                        .font(.caption2)
                        .foregroundStyle(Color.appTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
        .onChange(of: isSignUp) { _, _ in auth.error = nil; resetMessage = nil; inviteCode = "" }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
            if let until = auth.loginLockedUntil, until <= now {
                auth.loginLockedUntil = nil
            }
        }
        .sheet(isPresented: $showForgotPassword, onDismiss: { resetEmail = ""; resetMessage = nil; resetSuccess = false }) {
            forgotPasswordSheet
        }
    }

    private var forgotPasswordSheet: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()
            VStack(spacing: 24) {
                // Handle
                Capsule()
                    .fill(Color.appCard)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                VStack(spacing: 6) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hex: "4A9EF8"))
                    Text("Reset Password")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.appPrimary)
                    Text("Enter your email and we'll send you a link to reset your password.")
                        .font(.footnote)
                        .foregroundStyle(Color.appSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                authField("Email", text: $resetEmail, icon: "envelope.fill",
                          keyboard: .emailAddress, capitalize: .never)
                    .padding(.horizontal, 24)

                if let msg = resetMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(resetSuccess ? Color(hex: "34C759") : Color(hex: "FF6B6B"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    Task { await sendReset() }
                } label: {
                    Group {
                        if isResetting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Send Reset Link")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "4A9EF8"))
                    .foregroundStyle(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .disabled(resetEmail.isEmpty || isResetting || resetSuccess)

                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func sendReset() async {
        isResetting = true; defer { isResetting = false }
        do {
            try await auth.sendPasswordReset(email: resetEmail)
            resetSuccess = true
            resetMessage = "Check your inbox — we've sent a reset link to \(resetEmail)."
        } catch {
            resetSuccess = false
            resetMessage = error.localizedDescription
        }
    }

    private func authField(
        _ placeholder: String,
        text: Binding<String>,
        icon: String,
        keyboard: UIKeyboardType = .default,
        capitalize: TextInputAutocapitalization = .never,
        isSecure: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color(hex: "4A9EF8"))
                .frame(width: 20)
            if isSecure {
                SecureField(placeholder, text: text)
                    .foregroundStyle(Color.appPrimary)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(capitalize)
                    .foregroundStyle(Color.appPrimary)
            }
        }
        .padding()
        .background(Color.appInputBG)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Color helper
// ─────────────────────────────────────────────────────────────────────────────
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var val: UInt64 = 0
        Scanner(string: h).scanHexInt64(&val)
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8) & 0xFF) / 255
        let b = Double(val & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthService.shared)
}
