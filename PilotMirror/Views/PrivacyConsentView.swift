import SwiftUI

struct PrivacyConsentView: View {
    @EnvironmentObject var lang: LanguageService
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "0A1628").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "4A9EF8"))
                        .padding(.top, 48)

                    Text(lang.t("Datenschutz & Nutzungsbedingungen", "Privacy & Terms of Use"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(lang.t("Beta-Version — bitte lies die folgenden Hinweise sorgfältig.",
                                "Beta version — please read the following information carefully."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        policySection(
                            icon: "person.fill",
                            color: "4A9EF8",
                            title: lang.t("Welche Daten werden gespeichert?", "What data is stored?"),
                            text: lang.t(
                                "Deine E-Mail-Adresse, deine Antworten im Self-Assessment sowie die anonymen Rückmeldungen der Personen, die du zur Umfrage eingeladen hast. Diese Daten werden in einer gesicherten Cloud-Datenbank (Supabase) gespeichert.",
                                "Your email address, your self-assessment answers, and the anonymous responses from people you invited to the survey. This data is stored in a secure cloud database (Supabase)."
                            )
                        )

                        policySection(
                            icon: "sparkles",
                            color: "6B5EE4",
                            title: lang.t("KI-Analyse", "AI Analysis"),
                            text: lang.t(
                                "Zur Erstellung deines persönlichen Reports werden deine Antworten und die Umfrage-Ergebnisse an einen KI-Dienst (Groq / Llama) übermittelt. Die Übertragung erfolgt verschlüsselt über unsere eigene Serverinfrastruktur. Der KI-Anbieter speichert keine Anfragen dauerhaft.",
                                "To generate your personal report, your answers and survey results are sent to an AI service (Groq / Llama). Transmission is encrypted via our own server infrastructure. The AI provider does not permanently store requests."
                            )
                        )

                        policySection(
                            icon: "person.2.fill",
                            color: "34C759",
                            title: lang.t("Respondenten", "Respondents"),
                            text: lang.t(
                                "Personen, die deinen Feedback-Link ausfüllen, geben ihren Namen und ihre Beziehung zu dir an. Diese Angaben sind nur für dich und den KI-Report sichtbar — nicht für Dritte.",
                                "People who complete your feedback link provide their name and relationship to you. This information is only visible to you and used for the AI report — not shared with third parties."
                            )
                        )

                        policySection(
                            icon: "exclamationmark.triangle.fill",
                            color: "FF9F0A",
                            title: lang.t("Beta-Hinweis", "Beta Notice"),
                            text: lang.t(
                                "Dies ist eine Beta-Version. Gespeicherte Daten können jederzeit ohne Vorankündigung gelöscht werden. Die App ist nicht für professionelle Einzel- oder Eignungsdiagnostik geeignet und ersetzt keine qualifizierte Beratung.",
                                "This is a beta version. Stored data may be deleted at any time without notice. The app is not intended for professional or diagnostic assessments and does not replace qualified counseling."
                            )
                        )

                        policySection(
                            icon: "trash.fill",
                            color: "FF6B6B",
                            title: lang.t("Datenlöschung", "Data Deletion"),
                            text: lang.t(
                                "Du kannst die Löschung deiner Daten jederzeit durch das Löschen deines Accounts in der App veranlassen. Mit Registrierung stimmst du der Verarbeitung deiner Daten gemäß dieser Hinweise zu.",
                                "You can request deletion of your data at any time by deleting your account in the app. By registering, you consent to the processing of your data in accordance with these notices."
                            )
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }

                // Accept button
                Button(action: {
                    UserDefaults.standard.set(true, forKey: "pm_privacy_accepted")
                    onAccept()
                }) {
                    Text(lang.t("Verstanden & Fortfahren", "Understood & Continue"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "4A9EF8"))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private func policySection(icon: String, color: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: color))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: color).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
