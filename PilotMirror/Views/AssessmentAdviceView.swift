import SwiftUI

struct AssessmentAdviceView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        ZStack {
            Color(hex: "0A1628").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Preparation Guide")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if let type = auth.currentUser?.assessmentType {
                            Text(type.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: "4A9EF8"))
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .background(Color(hex: "4A9EF8").opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 16)

                    adviceCard(
                        icon: "person.3.fill", color: "4A9EF8",
                        title: "Group Exercise Tips",
                        tips: [
                            "Speak up within the first 2 minutes — silence is misread as disinterest",
                            "Acknowledge others' ideas before building on them",
                            "Watch your airtime — quality over quantity",
                            "Offer to summarise the group's position — shows leadership",
                            "Stay calm visibly — assessors watch body language as much as words",
                        ]
                    )

                    adviceCard(
                        icon: "mic.fill", color: "FF9F0A",
                        title: "Interview Tips",
                        tips: [
                            "Use STAR format: Situation, Task, Action, Result",
                            "Prepare 5 examples of decisions made under pressure",
                            "Show self-awareness — acknowledge a real weakness with a recovery story",
                            "Research the airline's values and align your answers",
                            "Practice answering in under 90 seconds per question",
                        ]
                    )

                    adviceCard(
                        icon: "arrow.triangle.branch", color: "34C759",
                        title: "Decision Making",
                        tips: [
                            "In simulators: state your intent out loud before acting",
                            "Practice time-boxed decisions — 30 seconds max for routine choices",
                            "Verbalize your risk assessment in role-play scenarios",
                            "If unsure, say what you're thinking — assessors value transparency",
                            "Show you can adapt when new information arrives mid-task",
                        ]
                    )

                    adviceCard(
                        icon: "brain.head.profile", color: "6B5EE4",
                        title: "Self-Awareness",
                        tips: [
                            "Know your personality profile — your report is your guide",
                            "If others see you as reserved — practice assertive phrasing",
                            "If others see you as dominant — practice active listening",
                            "Be consistent between interview answers and observed behavior",
                            "Assessors compare what you say about yourself with what they see",
                        ]
                    )

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Preparation Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func adviceCard(icon: String, color: String, title: String, tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: color))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: color).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(tips.enumerated()), id: \.offset) { i, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(Color(hex: color))
                            .frame(width: 20, height: 20)
                            .background(Color(hex: color).opacity(0.12))
                            .clipShape(Circle())
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        AssessmentAdviceView()
            .environmentObject(AuthService.shared)
    }
}
