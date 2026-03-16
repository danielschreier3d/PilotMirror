import SwiftUI

struct AssessmentAdviceView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var lang: LanguageService
    @ObservedObject private var aiService = AIAnalysisService.shared

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(lang.t("Vorbereitungsguide", "Preparation Guide"))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appPrimary)
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
                        title: lang.t("Gruppenübung", "Group Exercise"),
                        isPersonalized: !(aiService.result?.groupExerciseTips ?? []).isEmpty,
                        tips: aiService.result.flatMap { $0.groupExerciseTips.isEmpty ? nil : $0.groupExerciseTips }
                            ?? (lang.isGerman ? [
                            "Melde dich innerhalb der ersten 2 Minuten zu Wort — Schweigen wird als Desinteresse gewertet",
                            "Erkenne die Ideen anderer an, bevor du sie weiterentwickelst",
                            "Achte auf deine Redezeit — Qualität vor Quantität",
                            "Biete an, die Gruppenposition zusammenzufassen — zeigt Führungsstärke",
                            "Bleib sichtbar ruhig — Assessoren beobachten Körpersprache genauso wie Worte",
                        ] : [
                            "Speak up within the first 2 minutes — silence is misread as disinterest",
                            "Acknowledge others' ideas before building on them",
                            "Watch your airtime — quality over quantity",
                            "Offer to summarise the group's position — shows leadership",
                            "Stay visibly calm — assessors watch body language as much as words",
                        ])
                    )

                    adviceCard(
                        icon: "mic.fill", color: "FF9F0A",
                        title: lang.t("Interview", "Interview"),
                        isPersonalized: !(aiService.result?.interviewTips ?? []).isEmpty,
                        tips: aiService.result.flatMap { $0.interviewTips.isEmpty ? nil : $0.interviewTips }
                            ?? (lang.isGerman ? [
                            "Nutze das STAR-Format: Situation, Task (Aufgabe), Action (Handlung), Result (Ergebnis)",
                            "Bereite 5 Beispiele für Entscheidungen unter Druck vor",
                            "Zeige Selbstreflexion — benenne eine echte Schwäche mit einer Entwicklungsgeschichte",
                            "Recherchiere die Werte der Airline und stimme deine Antworten darauf ab",
                            "Übe, Antworten in unter 90 Sekunden zu geben",
                        ] : [
                            "Use STAR format: Situation, Task, Action, Result",
                            "Prepare 5 examples of decisions made under pressure",
                            "Show self-awareness — acknowledge a real weakness with a recovery story",
                            "Research the airline's values and align your answers",
                            "Practice answering in under 90 seconds per question",
                        ])
                    )

                    adviceCard(
                        icon: "arrow.triangle.branch", color: "34C759",
                        title: lang.t("Entscheidungsverhalten", "Decision Making"),
                        isPersonalized: !(aiService.result?.decisionMakingTips ?? []).isEmpty,
                        tips: aiService.result.flatMap { $0.decisionMakingTips.isEmpty ? nil : $0.decisionMakingTips }
                            ?? (lang.isGerman ? [
                            "Im Simulator: Kommuniziere deine Absicht laut, bevor du handelst",
                            "Übe zeitlich begrenzte Entscheidungen — max. 30 Sekunden für Routineentscheidungen",
                            "Verbalisiere deine Risikoeinschätzung in Rollenspielszenarien",
                            "Bei Unsicherheit: Sag, was du denkst — Assessoren schätzen Transparenz",
                            "Zeige, dass du dich anpassen kannst, wenn neue Informationen mitten in einer Aufgabe eintreffen",
                        ] : [
                            "In simulators: state your intent out loud before acting",
                            "Practice time-boxed decisions — 30 seconds max for routine choices",
                            "Verbalize your risk assessment in role-play scenarios",
                            "If unsure, say what you're thinking — assessors value transparency",
                            "Show you can adapt when new information arrives mid-task",
                        ])
                    )

                    adviceCard(
                        icon: "brain.head.profile", color: "6B5EE4",
                        title: lang.t("Selbstwahrnehmung", "Self-Awareness"),
                        isPersonalized: !(aiService.result?.selfAwarenessTips ?? []).isEmpty,
                        tips: aiService.result.flatMap { $0.selfAwarenessTips.isEmpty ? nil : $0.selfAwarenessTips }
                            ?? (lang.isGerman ? [
                            "Kenne dein Persönlichkeitsprofil — dein Report ist dein Leitfaden",
                            "Falls andere dich als zurückhaltend wahrnehmen: Übe selbstbewussteres Auftreten",
                            "Falls andere dich als dominant wahrnehmen: Übe aktives Zuhören",
                            "Sei konsistent zwischen deinen Interview-Antworten und deinem beobachtbaren Verhalten",
                            "Assessoren vergleichen, was du über dich sagst, mit dem, was sie beobachten",
                        ] : [
                            "Know your personality profile — your report is your guide",
                            "If others see you as reserved — practice assertive phrasing",
                            "If others see you as dominant — practice active listening",
                            "Be consistent between interview answers and observed behavior",
                            "Assessors compare what you say about yourself with what they see",
                        ])
                    )

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle(lang.t("Vorbereitungsguide", "Preparation Guide"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func adviceCard(icon: String, color: String, title: String, isPersonalized: Bool = false, tips: [String]) -> some View {
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
                    .foregroundStyle(Color.appPrimary)
                if isPersonalized {
                    Text(lang.t("Personalisiert", "Personalized"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: "34C759"))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(hex: "34C759").opacity(0.15))
                        .clipShape(Capsule())
                }
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
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        AssessmentAdviceView()
            .environmentObject(AuthService.shared)
            .environmentObject(LanguageService.shared)
    }
}
