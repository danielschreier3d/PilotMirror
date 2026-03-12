import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0A1628"), Color(hex: "0D2B55")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + headline
                VStack(spacing: 16) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color(hex: "4A9EF8"))
                        .shadow(color: Color(hex: "4A9EF8").opacity(0.4), radius: 20)

                    Text("PilotMirror")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Understand how others perceive you\nbefore your pilot assessment.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                // Value props
                VStack(spacing: 14) {
                    valueRow(icon: "person.2.fill",        color: Color(hex: "4A9EF8"),
                             text: "Collect anonymous feedback from people you trust")
                    valueRow(icon: "chart.bar.fill",        color: Color(hex: "34C759"),
                             text: "Compare self-perception vs external perception")
                    valueRow(icon: "brain.head.profile",    color: Color(hex: "FF9F0A"),
                             text: "Get AI-powered advice for your assessment")
                }
                .padding(.horizontal, 32)

                Spacer()

                // Auth buttons
                VStack(spacing: 12) {
                    // Apple Sign In
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await auth.handleAppleSignIn(result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Google Sign In
                    Button {
                        Task { await auth.signInWithGoogle() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .medium))
                            Text("Continue with Google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.white)
                        .foregroundStyle(Color(hex: "1a1a1a"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(auth.isLoading)

                    // Email / Password
                    NavigationLink {
                        EmailAuthView()
                            .environmentObject(auth)
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Continue with Email")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    if let err = auth.error {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color(hex: "FF6B6B"))
                            .multilineTextAlignment(.center)
                    }

                    Text("By continuing you agree to our Terms & Privacy Policy.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .overlay {
            if auth.isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
        .navigationBarHidden(true)
    }

    private func valueRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Email Auth
// ─────────────────────────────────────────────────────────────────────────────
struct EmailAuthView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var isSignUp = true
    @State private var name     = ""
    @State private var email    = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            Color(hex: "0A1628").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Tab picker
                    Picker("Mode", selection: $isSignUp) {
                        Text("Create Account").tag(true)
                        Text("Sign In").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Fields
                    VStack(spacing: 14) {
                        if isSignUp {
                            authField("Full Name", text: $name, icon: "person.fill",
                                      keyboard: .default, capitalize: .words)
                        }
                        authField("Email", text: $email, icon: "envelope.fill",
                                  keyboard: .emailAddress, capitalize: .never)
                        authField("Password", text: $password, icon: "lock.fill", isSecure: true)
                    }
                    .padding(.horizontal)

                    // Action button
                    Button {
                        Task {
                            if isSignUp {
                                await auth.signUp(name: name, email: email, password: password)
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
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .disabled(auth.isLoading || email.isEmpty || password.isEmpty ||
                              (isSignUp && name.isEmpty))

                    // Error
                    if let err = auth.error {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color(hex: "FF6B6B"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle(isSignUp ? "Create Account" : "Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: auth.isAuthenticated) { _, authenticated in
            if authenticated { dismiss() }
        }
        .onDisappear { auth.error = nil }
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
                    .foregroundStyle(.white)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(capitalize)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(.white.opacity(0.08))
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
    NavigationStack {
        OnboardingView()
            .environmentObject(AuthService.shared)
    }
}
