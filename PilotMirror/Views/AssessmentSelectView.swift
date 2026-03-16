import SwiftUI

struct AssessmentSelectView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var lang: LanguageService
    @Binding var selectedAssessment: User.AssessmentType?

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text(lang.t("Für welches Assessment bereitest du dich vor?",
                                "Which assessment are you preparing for?"))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appPrimary)
                        .multilineTextAlignment(.center)

                    Text(lang.t("Hilft dabei, deinen KI-Report zu personalisieren.",
                                "This helps tailor your AI feedback report."))
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 32)

                // Assessment cards
                VStack(spacing: 14) {
                    ForEach(User.AssessmentType.allCases, id: \.self) { type in
                        AssessmentCard(
                            type: type,
                            isSelected: selectedAssessment == type
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedAssessment = type
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // CTA
                Button {
                    guard let type = selectedAssessment else { return }
                    auth.updateAssessmentType(type)
                } label: {
                    Text(lang.t("Weiter", "Continue"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(selectedAssessment != nil ? Color(hex: "4A9EF8") : Color.appBorder)
                        .foregroundStyle(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .animation(.easeInOut(duration: 0.2), value: selectedAssessment)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .disabled(selectedAssessment == nil)
            }
        }
    }
}

struct AssessmentCard: View {
    let type: User.AssessmentType
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var lang: LanguageService

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? Color(hex: "4A9EF8") : .white.opacity(0.6))
                    .frame(width: 52, height: 52)
                    .background(isSelected ? Color(hex: "4A9EF8").opacity(0.15) : Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.headline)
                        .foregroundStyle(Color.appPrimary)
                    Text(lang.isGerman ? type.descriptionDE : type.descriptionEN)
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
                            .strokeBorder(isSelected ? Color(hex: "4A9EF8").opacity(0.8) : .clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AssessmentSelectView(selectedAssessment: .constant(.general))
        .environmentObject(AuthService.shared)
}
