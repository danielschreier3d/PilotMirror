import SwiftUI

struct FlightLicenseSelectView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var lang: LanguageService
    @Binding var flightLicenses: [User.FlightLicense]?

    @State private var selected: Set<User.FlightLicense> = []

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text(lang.t("Hast du bereits eine Fluglizenz?",
                                "Do you have a flight licence?"))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appPrimary)
                        .multilineTextAlignment(.center)

                    Text(lang.t("Mehrfachauswahl möglich",
                                "Multiple selections possible"))
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 28)
                .padding(.horizontal, 24)

                // License cards
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(User.FlightLicense.allCases, id: \.self) { license in
                            LicenseCard(
                                license: license,
                                isSelected: selected.contains(license),
                                isGerman: lang.isGerman
                            ) {
                                toggleLicense(license)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                // CTA
                Button {
                    let result = Array(selected)
                    auth.updateFlightLicenses(result)
                    flightLicenses = result.isEmpty ? [.none] : result
                } label: {
                    Text(lang.t("Weiter", "Continue"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(!selected.isEmpty ? Color(hex: "4A9EF8") : Color.appBorder)
                        .foregroundStyle(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .animation(.easeInOut(duration: 0.2), value: selected.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .disabled(selected.isEmpty)
            }
        }
    }

    private func toggleLicense(_ license: User.FlightLicense) {
        withAnimation(.spring(response: 0.3)) {
            if license == .none {
                // "Keine" clears all others
                selected = [.none]
            } else {
                selected.remove(.none)
                if selected.contains(license) {
                    selected.remove(license)
                } else {
                    selected.insert(license)
                }
                if selected.isEmpty { selected = [.none] }
            }
        }
    }
}

// MARK: - License Card

private struct LicenseCard: View {
    let license: User.FlightLicense
    let isSelected: Bool
    let isGerman: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: license.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color(hex: "4A9EF8") : .white.opacity(0.6))
                    .frame(width: 48, height: 48)
                    .background(isSelected ? Color(hex: "4A9EF8").opacity(0.15) : Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 3) {
                    Text(isGerman ? license.labelDE : license.labelEN)
                        .font(.headline)
                        .foregroundStyle(Color.appPrimary)
                    Text(isGerman ? license.descriptionDE : license.descriptionEN)
                        .font(.caption)
                        .foregroundStyle(Color.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color(hex: "4A9EF8") : .white.opacity(0.3))
                    .font(.title3)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                isSelected ? Color(hex: "4A9EF8").opacity(0.8) : .clear,
                                lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FlightLicenseSelectView(flightLicenses: .constant(nil))
        .environmentObject(AuthService.shared)
        .environmentObject(LanguageService.shared)
}
