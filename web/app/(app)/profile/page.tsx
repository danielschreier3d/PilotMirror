"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";

function t(de: string, en: string, g: boolean) { return g ? de : en; }

export default function ProfilePage() {
  const { user, isGerman, setLanguage, signOut, changePassword, resetSurveyData, deleteAccount, updateAssessmentType, updateFlightLicenses } = useAuth();
  const router = useRouter();

  const [showChangePassword, setShowChangePw] = useState(false);
  const [newPassword, setNewPassword]         = useState("");
  const [pwLoading, setPwLoading]             = useState(false);
  const [pwError, setPwError]                 = useState<string | null>(null);
  const [pwSuccess, setPwSuccess]             = useState(false);

  const [langSetting, setLangSetting] = useState(
    typeof localStorage !== "undefined" ? (localStorage.getItem("pm_language") ?? "auto") : "auto"
  );

  const [appearance, setAppearance] = useState(
    typeof localStorage !== "undefined" ? (localStorage.getItem("pm_appearance") ?? "dark") : "dark"
  );

  function changeAppearance(val: string) {
    setAppearance(val);
    localStorage.setItem("pm_appearance", val);
    const html = document.documentElement;
    if (val === "dark") html.classList.add("dark");
    else if (val === "light") html.classList.remove("dark");
    else {
      const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
      if (prefersDark) html.classList.add("dark"); else html.classList.remove("dark");
    }
  }

  async function handleChangePw(e: React.FormEvent) {
    e.preventDefault();
    setPwLoading(true); setPwError(null);
    try {
      await changePassword(newPassword);
      setPwSuccess(true);
    } catch (err: unknown) {
      setPwError(err instanceof Error ? err.message : "Error");
    } finally {
      setPwLoading(false);
    }
  }

  return (
    <div className="min-h-svh" style={{ background: "var(--app-bg)" }}>
      {/* Nav bar */}
      <div className="flex items-center px-4 gap-2" style={{
        paddingTop: "max(env(safe-area-inset-top, 12px), 12px)", paddingBottom: 12,
        borderBottom: "1px solid var(--app-border)", background: "var(--app-bg)" }}>
        <button onClick={() => router.back()} className="w-8 h-8 flex items-center justify-center rounded-full text-sm"
          style={{ background: "var(--app-input)" }}>←</button>
        <h1 className="flex-1 text-center font-bold text-base" style={{ color: "var(--app-primary)" }}>
          {t("Profil & Einstellungen","Profile & Settings",isGerman)}
        </h1>
        <div className="w-8" />
      </div>

      <div className="px-4 py-4 space-y-4 pb-safe">
        {/* User info */}
        <div className="card p-5 space-y-1">
          <p className="font-bold text-base" style={{ color: "var(--app-primary)" }}>{user?.name}</p>
          <p className="text-sm" style={{ color: "var(--app-secondary)" }}>{user?.email}</p>
          {user?.assessmentType && (
            <span className="inline-block mt-2 text-xs px-3 py-1 rounded-full font-semibold"
              style={{ background: "rgba(74,158,248,0.15)", color: "#4A9EF8" }}>
              {user.assessmentType}
            </span>
          )}
        </div>

        {/* Language */}
        <SettingsSection title={t("Sprache","Language",isGerman)}>
          <div className="flex gap-2">
            {[{v:"de",label:"Deutsch"},{v:"en",label:"English"},{v:"auto",label:"Auto"}].map(({v,label}) => (
              <button key={v} onClick={() => { setLangSetting(v); setLanguage(v as "de"|"en"|"auto"); }}
                className="flex-1 py-2 rounded-xl text-xs font-semibold"
                style={{
                  background: langSetting === v ? "#4A9EF8" : "var(--app-input)",
                  color: langSetting === v ? "white" : "var(--app-secondary)",
                }}>
                {label}
              </button>
            ))}
          </div>
        </SettingsSection>

        {/* Appearance */}
        <SettingsSection title={t("Erscheinungsbild","Appearance",isGerman)}>
          <div className="flex gap-2">
            {[{v:"dark",de:"Dunkel",en:"Dark"},{v:"light",de:"Hell",en:"Light"},{v:"system",de:"System",en:"System"}].map(({v,de,en}) => (
              <button key={v} onClick={() => changeAppearance(v)}
                className="flex-1 py-2 rounded-xl text-xs font-semibold"
                style={{
                  background: appearance === v ? "#4A9EF8" : "var(--app-input)",
                  color: appearance === v ? "white" : "var(--app-secondary)",
                }}>
                {isGerman ? de : en}
              </button>
            ))}
          </div>
        </SettingsSection>

        {/* Assessment type */}
        <SettingsSection title={t("Assessment-Typ","Assessment Type",isGerman)}>
          <button onClick={() => router.push("/setup/assessment")}
            className="w-full text-left flex items-center justify-between py-2"
            style={{ color: "var(--app-primary)" }}>
            <span className="text-sm">{user?.assessmentType ?? t("Nicht gesetzt","Not set",isGerman)}</span>
            <span style={{ color: "#4A9EF8" }}>›</span>
          </button>
        </SettingsSection>

        {/* Flight licenses */}
        <SettingsSection title={t("Fluglizenzen","Flight Licences",isGerman)}>
          <button onClick={() => router.push("/setup/licenses")}
            className="w-full text-left flex items-center justify-between py-2"
            style={{ color: "var(--app-primary)" }}>
            <span className="text-sm">
              {user?.flightLicenses?.join(", ") ?? t("Nicht gesetzt","Not set",isGerman)}
            </span>
            <span style={{ color: "#4A9EF8" }}>›</span>
          </button>
        </SettingsSection>

        {/* Change password */}
        <SettingsSection title={t("Passwort ändern","Change Password",isGerman)}>
          {showChangePassword ? (
            <form onSubmit={handleChangePw} className="space-y-3">
              <input type="password" value={newPassword} onChange={(e) => setNewPassword(e.target.value)}
                placeholder={t("Neues Passwort","New password",isGerman)}
                className="input-field" required minLength={6} />
              {pwError && <p className="text-xs" style={{ color: "#FF6B6B" }}>{pwError}</p>}
              {pwSuccess && <p className="text-xs" style={{ color: "#34C759" }}>
                {t("Passwort geändert ✓","Password changed ✓",isGerman)}</p>}
              <button type="submit" className="btn-primary" style={{ height: 40, fontSize: "0.875rem" }}
                disabled={pwLoading || !newPassword}>
                {pwLoading ? <div className="spinner" /> : t("Speichern","Save",isGerman)}
              </button>
            </form>
          ) : (
            <button onClick={() => setShowChangePw(true)}
              className="text-sm" style={{ color: "#4A9EF8" }}>
              {t("Passwort ändern","Change password",isGerman)} →
            </button>
          )}
        </SettingsSection>

        {/* Reset survey data */}
        <SettingsSection title={t("Daten zurücksetzen","Reset Survey Data",isGerman)}>
          <p className="text-xs mb-3" style={{ color: "var(--app-secondary)" }}>
            {t("Löscht deine Self-Assessment-Antworten, Feedback-Links und den KI-Report.",
               "Deletes your self-assessment responses, feedback links, and AI report.",isGerman)}
          </p>
          <button onClick={async () => {
            if (confirm(t("Alle Umfragedaten wirklich löschen?","Really delete all survey data?",isGerman))) {
              await resetSurveyData();
              router.replace("/dashboard");
            }
          }} className="text-sm font-semibold" style={{ color: "#FF9F0A" }}>
            {t("Zurücksetzen","Reset data",isGerman)}
          </button>
        </SettingsSection>

        {/* Sign out */}
        <button onClick={() => { signOut(); router.replace("/login"); }}
          className="w-full py-3 rounded-2xl font-semibold text-sm"
          style={{ background: "var(--app-input)", color: "#FF6B6B" }}>
          {t("Abmelden","Sign out",isGerman)}
        </button>

        {/* Delete account */}
        <button onClick={async () => {
          if (confirm(t("Konto und alle Daten wirklich löschen? Dies kann nicht rückgängig gemacht werden.",
                        "Really delete account and all data? This cannot be undone.",isGerman))) {
            await deleteAccount();
            router.replace("/login");
          }
        }} className="w-full py-2 text-xs font-semibold"
          style={{ color: "var(--app-tertiary)" }}>
          {t("Konto löschen","Delete account",isGerman)}
        </button>

        <div className="h-4" />
      </div>
    </div>
  );
}

function SettingsSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="card p-4 space-y-3">
      <p className="text-xs font-bold uppercase tracking-wide" style={{ color: "var(--app-tertiary)" }}>{title}</p>
      {children}
    </div>
  );
}
