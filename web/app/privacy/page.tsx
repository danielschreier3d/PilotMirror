"use client";

import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";

export default function PrivacyPage() {
  const { user, isGerman } = useAuth();
  const router = useRouter();

  function accept() {
    localStorage.setItem("pm_privacy_accepted", "true");
    if (!user?.assessmentType) { router.replace("/setup/assessment"); return; }
    if (!user?.flightLicenses)  { router.replace("/setup/licenses");   return; }
    router.replace("/dashboard");
  }

  return (
    <div className="flex items-center justify-center min-h-svh px-6" style={{ background: "var(--app-bg)" }}>
      <div className="max-w-sm w-full space-y-6 fade-in">
        <div className="text-center space-y-3">
          <div className="text-5xl">🔐</div>
          <h1 className="text-2xl font-bold" style={{ color: "var(--app-primary)" }}>
            {isGerman ? "Datenschutz & Einwilligung" : "Privacy & Consent"}
          </h1>
        </div>

        <div className="card p-5 space-y-4 text-sm" style={{ color: "var(--app-secondary)" }}>
          {isGerman ? (
            <>
              <p><strong style={{ color: "var(--app-primary)" }}>Was wir speichern:</strong> Deine Antworten auf den Fragebogen sowie das Feedback, das andere über dich abgeben, werden in unserer Datenbank gespeichert.</p>
              <p><strong style={{ color: "var(--app-primary)" }}>Zweck:</strong> Diese Daten werden ausschließlich verwendet, um dir eine KI-basierte Auswertung zu erstellen und dich auf dein Piloten-Auswahlverfahren vorzubereiten.</p>
              <p><strong style={{ color: "var(--app-primary)" }}>Anonym:</strong> Die Antworten deiner Feedback-Geber werden anonymisiert verarbeitet. Namen werden nur zur Identifikation gespeichert, nicht in der Auswertung angezeigt.</p>
              <p><strong style={{ color: "var(--app-primary)" }}>Löschung:</strong> Du kannst dein Konto und alle Daten jederzeit in den Einstellungen löschen.</p>
            </>
          ) : (
            <>
              <p><strong style={{ color: "var(--app-primary)" }}>What we store:</strong> Your questionnaire responses and feedback from others are stored in our database.</p>
              <p><strong style={{ color: "var(--app-primary)" }}>Purpose:</strong> This data is used solely to generate your AI-based analysis and prepare you for your pilot assessment.</p>
              <p><strong style={{ color: "var(--app-primary)" }}>Anonymous:</strong> Responses from your feedback providers are processed anonymously.</p>
              <p><strong style={{ color: "var(--app-primary)" }}>Deletion:</strong> You can delete your account and all data at any time in settings.</p>
            </>
          )}
        </div>

        <button onClick={accept} className="btn-primary">
          {isGerman ? "Verstanden & Akzeptieren" : "Understood & Accept"}
        </button>
      </div>
    </div>
  );
}
