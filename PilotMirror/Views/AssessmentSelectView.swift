import SwiftUI

struct AssessmentSelectView: View {
    @EnvironmentObject var auth: AuthService
    @Binding var selectedAssessment: User.AssessmentType?

    var body: some View {
        ZStack {
            Color(hex: "0A1628").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Which assessment are\nyou preparing for?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("This helps tailor your AI feedback report.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
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
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(selectedAssessment != nil ? Color(hex: "4A9EF8") : Color.white.opacity(0.15))
                        .foregroundStyle(.white)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? Color(hex: "4A9EF8") : .white.opacity(0.6))
                    .frame(width: 52, height: 52)
                    .background(isSelected ? Color(hex: "4A9EF8").opacity(0.15) : .white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
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
    AssessmentSelectView(selectedAssessment: .constant(.dlr))
        .environmentObject(AuthService.shared)
}
