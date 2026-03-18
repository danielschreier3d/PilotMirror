"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";

function t(de: string, en: string, g: boolean) { return g ? de : en; }

// ─── SVG Icons ────────────────────────────────────────────────────────────────

function PersonSVG() {
  return (
    <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
      <circle cx="20" cy="20" r="20" fill="#4A9EF8" />
      <circle cx="20" cy="15" r="7" fill="white" />
      <path d="M6 36c0-7.732 6.268-10 14-10s14 2.268 14 10" fill="white" />
    </svg>
  );
}

function AirplaneSVG({ color = "#4A9EF8", size = 12 }: { color?: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <path d="M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z"/>
    </svg>
  );
}

function SunSVG({ color = "currentColor" }: { color?: string }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round">
      <circle cx="12" cy="12" r="4"/>
      <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/>
    </svg>
  );
}

function MoonSVG({ color = "currentColor" }: { color?: string }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill={color}>
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>
      <circle cx="18" cy="4" r="1.5" fill={color} />
      <circle cx="20.5" cy="7" r="1" fill={color} />
    </svg>
  );
}

function CircleHalfSVG({ color = "currentColor" }: { color?: string }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2">
      <circle cx="12" cy="12" r="10"/>
      <path d="M12 2v20" stroke={color} strokeWidth="2"/>
      <path d="M12 2a10 10 0 0 1 0 20" fill={color} stroke="none"/>
    </svg>
  );
}

function SignOutSVG({ color = "currentColor" }: { color?: string }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
      <polyline points="16 17 21 12 16 7"/>
      <line x1="21" y1="12" x2="9" y2="12"/>
    </svg>
  );
}

function ResetSVG({ color = "currentColor" }: { color?: string }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/>
      <path d="M3 3v5h5"/>
    </svg>
  );
}

function TrashSVG({ color = "currentColor" }: { color?: string }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="3 6 5 6 21 6"/>
      <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>
      <path d="M10 11v6M14 11v6"/>
      <path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/>
    </svg>
  );
}

function CloseSVG() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
      <path d="M18 6 6 18M6 6l12 12"/>
    </svg>
  );
}

// ─── Page ────────────────────────────────────────────────────────────────────

export default function ProfilePage() {
  const { user, isGerman, setLanguage, signOut, changePassword, resetSurveyData, deleteAccount } = useAuth();
  const router = useRouter();

  const [newPassword, setNewPassword]       = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [pwLoading, setPwLoading]           = useState(false);
  const [pwError, setPwError]               = useState<string | null>(null);
  const [pwSuccess, setPwSuccess]           = useState(false);

  const [langSetting, setLangSetting] = useState(
    typeof localStorage !== "undefined"
      ? (localStorage.getItem("pm_language") ?? (isGerman ? "de" : "en"))
      : (isGerman ? "de" : "en")
  );

  const [appearance, setAppearance] = useState(
    typeof localStorage !== "undefined" ? (localStorage.getItem("pm_appearance") ?? "dark") : "dark"
  );

  function changeLang(val: "de" | "en") {
    setLangSetting(val);
    setLanguage(val);
  }

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
    if (newPassword !== confirmPassword) { setPwError(t("Passwörter stimmen nicht überein","Passwords do not match",isGerman)); return; }
    setPwLoading(true); setPwError(null); setPwSuccess(false);
    try {
      await changePassword(newPassword);
      setPwSuccess(true); setNewPassword(""); setConfirmPassword("");
    } catch (err: unknown) {
      setPwError(err instanceof Error ? err.message : "Error");
    } finally {
      setPwLoading(false);
    }
  }

  const licenses = user?.flightLicenses?.filter(l => l !== "None") ?? [];

  return (
    <div className="min-h-svh" style={{ background: "var(--app-bg)" }}>
      {/* Header */}
      <div className="flex items-center px-5" style={{
        paddingTop: "max(env(safe-area-inset-top, 20px), 20px)", paddingBottom: 16,
      }}>
        <h1 className="flex-1 text-2xl font-bold" style={{ color: "var(--app-primary)" }}>
          {t("Profil & Einstellungen", "Profile & Settings", isGerman)}
        </h1>
        <button onClick={() => router.back()}
          className="w-9 h-9 flex items-center justify-center rounded-full ios-press"
          style={{ background: "var(--app-input)", color: "var(--app-secondary)" }}>
          <CloseSVG />
        </button>
      </div>

      <div className="px-4 pb-safe space-y-3">

        {/* Profile card */}
        <div className="rounded-2xl p-4 flex items-center gap-4"
          style={{ background: "var(--app-card)", border: "1px solid var(--app-border)" }}>
          <PersonSVG />
          <div className="flex-1 min-w-0">
            <p className="font-bold text-lg leading-tight" style={{ color: "var(--app-primary)" }}>
              {user?.name}
            </p>
            <p className="text-sm mt-0.5" style={{ color: "var(--app-secondary)" }}>{user?.email}</p>
            <div className="flex flex-wrap gap-1.5 mt-2">
              {user?.assessmentType && (
                <span className="flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold"
                  style={{ background: "rgba(74,158,248,0.15)", color: "#4A9EF8" }}>
                  <AirplaneSVG color="#4A9EF8" size={11} />
                  {user.assessmentType}
                </span>
              )}
              {licenses.map(l => (
                <span key={l} className="flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold"
                  style={{ background: "rgba(52,199,89,0.15)", color: "#34C759" }}>
                  <AirplaneSVG color="#34C759" size={11} />
                  {l}
                </span>
              ))}
            </div>
          </div>
        </div>

        {/* SPRACHE */}
        <Section title={t("SPRACHE", "LANGUAGE", isGerman)}>
          <div className="flex gap-2 p-1 rounded-2xl" style={{ background: "var(--app-input)" }}>
            {([["de","DE","Deutsch"],["en","EN","English"]] as const).map(([v, abbr, full]) => (
              <button key={v} onClick={() => changeLang(v)}
                className="flex-1 py-3 rounded-xl ios-press transition-colors"
                style={{
                  background: langSetting === v ? "#4A9EF8" : "transparent",
                }}>
                <p className="font-bold text-lg leading-none" style={{ color: langSetting === v ? "white" : "var(--app-secondary)" }}>{abbr}</p>
                <p className="text-xs mt-0.5" style={{ color: langSetting === v ? "rgba(255,255,255,0.8)" : "var(--app-tertiary)" }}>{full}</p>
              </button>
            ))}
          </div>
        </Section>

        {/* DARSTELLUNG */}
        <Section title={t("DARSTELLUNG", "APPEARANCE", isGerman)}>
          <div className="flex gap-2 p-1 rounded-2xl" style={{ background: "var(--app-input)" }}>
            {([
              { v: "light", de: "Hell",   en: "Light",  Icon: SunSVG  },
              { v: "dark",  de: "Dunkel", en: "Dark",   Icon: MoonSVG },
              { v: "system",de: "System", en: "System", Icon: CircleHalfSVG },
            ]).map(({ v, de, en, Icon }) => {
              const sel = appearance === v;
              return (
                <button key={v} onClick={() => changeAppearance(v)}
                  className="flex-1 py-2.5 rounded-xl flex flex-col items-center gap-1 ios-press"
                  style={{ background: sel ? "#4A9EF8" : "transparent" }}>
                  <Icon color={sel ? "white" : "var(--app-secondary)"} />
                  <p className="text-xs font-semibold" style={{ color: sel ? "white" : "var(--app-secondary)" }}>
                    {isGerman ? de : en}
                  </p>
                </button>
              );
            })}
          </div>
        </Section>

        {/* PASSWORT ÄNDERN */}
        <Section title={t("PASSWORT ÄNDERN", "CHANGE PASSWORD", isGerman)}>
          <form onSubmit={handleChangePw} className="space-y-2">
            <input type="password" value={newPassword}
              onChange={(e) => { setNewPassword(e.target.value); setPwError(null); setPwSuccess(false); }}
              placeholder={t("Neues Passwort", "New password", isGerman)}
              className="input-field" required minLength={6} />
            <input type="password" value={confirmPassword}
              onChange={(e) => { setConfirmPassword(e.target.value); setPwError(null); }}
              placeholder={t("Bestätigen", "Confirm", isGerman)}
              className="input-field" required minLength={6} />
            {pwError && <p className="text-xs px-1" style={{ color: "#FF6B6B" }}>{pwError}</p>}
            {pwSuccess && <p className="text-xs px-1" style={{ color: "#34C759" }}>
              {t("Passwort geändert ✓", "Password changed ✓", isGerman)}</p>}
            <button type="submit" className="btn-primary mt-1" disabled={pwLoading || !newPassword || !confirmPassword}>
              {pwLoading ? <div className="spinner" /> : t("Passwort aktualisieren", "Update password", isGerman)}
            </button>
          </form>
        </Section>

        {/* KONTOVERWALTUNG */}
        <Section title={t("KONTOVERWALTUNG", "ACCOUNT", isGerman)}>
          <div className="space-y-2">
            <button onClick={async () => {
              if (confirm(t("Alle Umfragedaten wirklich löschen?","Really delete all survey data?",isGerman))) {
                await resetSurveyData();
                router.replace("/dashboard");
              }
            }} className="w-full flex items-center justify-center gap-2 py-3.5 rounded-2xl font-semibold text-sm ios-press"
              style={{ border: "1px solid rgba(255,159,10,0.5)", color: "#FF9F0A", background: "rgba(255,159,10,0.07)" }}>
              <ResetSVG color="#FF9F0A" />
              {t("Umfragedaten zurücksetzen", "Reset survey data", isGerman)}
            </button>
            <button onClick={async () => {
              if (confirm(t("Konto und alle Daten wirklich löschen? Dies kann nicht rückgängig gemacht werden.",
                            "Really delete account and all data? This cannot be undone.",isGerman))) {
                await deleteAccount();
                router.replace("/login");
              }
            }} className="w-full flex items-center justify-center gap-2 py-3.5 rounded-2xl font-semibold text-sm ios-press"
              style={{ border: "1px solid rgba(255,69,58,0.35)", color: "#FF453A", background: "rgba(255,69,58,0.1)" }}>
              <TrashSVG color="#FF453A" />
              {t("Account löschen", "Delete account", isGerman)}
            </button>
          </div>
        </Section>

        {/* Abmelden */}
        <button onClick={async () => { await signOut(); router.replace("/login"); }}
          className="w-full flex items-center justify-center gap-2 py-4 rounded-2xl font-semibold ios-press"
          style={{ background: "var(--app-card)", border: "1px solid var(--app-border)", color: "var(--app-secondary)" }}>
          <SignOutSVG color="var(--app-secondary)" />
          {t("Abmelden", "Sign out", isGerman)}
        </button>

        <div className="h-4" />
      </div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-2xl p-4" style={{ background: "var(--app-card)", border: "1px solid var(--app-border)" }}>
      <p className="text-xs font-bold tracking-wider mb-3" style={{ color: "var(--app-tertiary)" }}>{title}</p>
      {children}
    </div>
  );
}
