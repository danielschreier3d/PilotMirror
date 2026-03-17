"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { supabase } from "@/lib/supabase";

export default function LoginPage() {
  const { signIn, signUp, sendPasswordReset, isAuthenticated, isLoading, error, setError, user } = useAuth();
  const router = useRouter();

  const [mode, setMode]           = useState<"signin" | "signup">("signup");
  const [name, setName]           = useState("");
  const [email, setEmail]         = useState("");
  const [password, setPassword]   = useState("");
  const [inviteCode, setInviteCode] = useState("");
  const [showForgot, setShowForgot] = useState(false);
  const [resetEmail, setResetEmail] = useState("");
  const [resetSent, setResetSent]   = useState(false);
  const [resetLoading, setResetLoading] = useState(false);
  const [pendingConfirmation, setPendingConfirmation] = useState(false);

  // Redirect when already authenticated
  useEffect(() => {
    if (!isAuthenticated) return;
    const privacyAccepted = localStorage.getItem("pm_privacy_accepted") === "true";
    if (!privacyAccepted) { router.replace("/privacy"); return; }
    if (!user?.assessmentType) { router.replace("/setup/assessment"); return; }
    if (!user?.flightLicenses)  { router.replace("/setup/licenses");   return; }
    router.replace("/dashboard");
  }, [isAuthenticated, user, router]);

  // Handle email confirmation callback (Supabase redirects back here)
  useEffect(() => {
    const hash = window.location.hash;
    if (hash.includes("access_token")) {
      supabase.auth.getSession().then(({ data }) => {
        if (data.session) router.replace("/");
      });
    }
  }, [router]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (mode === "signup") {
      await signUp(name, email, password, inviteCode);
      // Check if email confirmation needed
      const { data } = await supabase.auth.getSession();
      if (!data.session) setPendingConfirmation(true);
    } else {
      await signIn(email, password);
    }
  }

  async function handleReset(e: React.FormEvent) {
    e.preventDefault();
    setResetLoading(true);
    try {
      await sendPasswordReset(resetEmail);
      setResetSent(true);
    } catch { /* handled */ } finally {
      setResetLoading(false);
    }
  }

  if (pendingConfirmation) {
    return (
      <div className="flex items-center justify-center min-h-svh px-6" style={{ background: "var(--app-bg)" }}>
        <div className="card p-8 max-w-sm w-full text-center space-y-4 fade-in">
          <div className="text-4xl">📧</div>
          <h2 className="text-xl font-bold" style={{ color: "var(--app-primary)" }}>
            Check your inbox
          </h2>
          <p style={{ color: "var(--app-secondary)" }} className="text-sm">
            We sent a confirmation link to <strong>{email}</strong>. Click it to activate your account.
          </p>
          <button onClick={() => setPendingConfirmation(false)}
            className="text-sm" style={{ color: "#4A9EF8" }}>
            Back to sign in
          </button>
        </div>
      </div>
    );
  }

  if (showForgot) {
    return (
      <div className="flex items-center justify-center min-h-svh px-6" style={{ background: "var(--app-bg)" }}>
        <div className="card p-8 max-w-sm w-full space-y-6 fade-in">
          <button onClick={() => setShowForgot(false)} className="text-sm flex items-center gap-1" style={{ color: "#4A9EF8" }}>
            ← Back
          </button>
          <div className="text-center space-y-2">
            <div className="text-4xl">🔑</div>
            <h2 className="text-xl font-bold" style={{ color: "var(--app-primary)" }}>Reset Password</h2>
            <p className="text-sm" style={{ color: "var(--app-secondary)" }}>
              Enter your email and we&apos;ll send you a reset link.
            </p>
          </div>
          {resetSent ? (
            <div className="text-center text-sm" style={{ color: "#34C759" }}>
              ✓ Reset link sent to {resetEmail}
            </div>
          ) : (
            <form onSubmit={handleReset} className="space-y-4">
              <input type="email" value={resetEmail} onChange={(e) => setResetEmail(e.target.value)}
                placeholder="Email" className="input-field" required />
              <button type="submit" className="btn-primary" disabled={resetLoading || !resetEmail}>
                {resetLoading ? <div className="spinner" /> : "Send Reset Link"}
              </button>
            </form>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center min-h-svh" style={{ background: "var(--app-bg)" }}>
      <div className="w-full max-w-sm px-6 py-10 space-y-8 fade-in">
        {/* Logo */}
        <div className="text-center space-y-3">
          <div className="text-7xl" style={{ filter: "drop-shadow(0 0 20px rgba(74,158,248,0.5))" }}>✈️</div>
          <h1 className="text-3xl font-bold" style={{ color: "var(--app-primary)", letterSpacing: "-0.5px" }}>
            PilotMirror
          </h1>
          <p className="text-sm" style={{ color: "var(--app-secondary)" }}>
            Understand how others perceive you<br />before your pilot assessment.
          </p>
        </div>

        {/* Tab picker */}
        <div className="flex rounded-xl overflow-hidden border" style={{ borderColor: "var(--app-border)" }}>
          {(["signup","signin"] as const).map((m) => (
            <button key={m} onClick={() => { setMode(m); setError(null); }}
              className="flex-1 py-2.5 text-sm font-semibold transition-all"
              style={{
                background: mode === m ? "#4A9EF8" : "var(--app-input)",
                color: mode === m ? "white" : "var(--app-secondary)",
              }}>
              {m === "signup" ? "Create Account" : "Sign In"}
            </button>
          ))}
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-3">
          {mode === "signup" && (
            <AuthInput icon="👤" placeholder="Full Name" value={name}
              onChange={setName} autoComplete="name" capitalize />
          )}
          <AuthInput icon="✉️" placeholder="Email" value={email}
            onChange={setEmail} type="email" autoComplete="email" />
          <AuthInput icon="🔒" placeholder="Password" value={password}
            onChange={setPassword} type="password" autoComplete={mode === "signup" ? "new-password" : "current-password"} />
          {mode === "signup" && (
            <AuthInput icon="🎟️" placeholder="Invite Code" value={inviteCode}
              onChange={(v) => setInviteCode(v.toUpperCase())} autoComplete="off" />
          )}

          {error && (
            <p className="text-sm text-center" style={{ color: "#FF6B6B" }}>{error}</p>
          )}

          <button type="submit" className="btn-primary mt-2"
            disabled={isLoading || !email || !password ||
              (mode === "signup" && (!name || !inviteCode))}>
            {isLoading ? <div className="spinner" /> : (mode === "signup" ? "Create Account" : "Sign In")}
          </button>

          {mode === "signin" && (
            <button type="button" onClick={() => setShowForgot(true)}
              className="w-full text-sm text-center py-1" style={{ color: "rgba(74,158,248,0.8)" }}>
              Forgot password?
            </button>
          )}
        </form>

        <p className="text-xs text-center" style={{ color: "var(--app-tertiary)" }}>
          By continuing you agree to our Terms &amp; Privacy Policy.
        </p>
      </div>
    </div>
  );
}

// ─── Reusable input ───────────────────────────────────────────────────────────
function AuthInput({
  icon, placeholder, value, onChange, type = "text",
  autoComplete, capitalize = false,
}: {
  icon: string; placeholder: string; value: string;
  onChange: (v: string) => void; type?: string;
  autoComplete?: string; capitalize?: boolean;
}) {
  return (
    <div className="flex items-center gap-3 px-4 rounded-xl"
      style={{ background: "var(--app-input)", border: "1px solid var(--app-border)", height: 52 }}>
      <span className="text-base">{icon}</span>
      <input
        type={type}
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        autoComplete={autoComplete}
        autoCapitalize={capitalize ? "words" : "none"}
        autoCorrect="off"
        spellCheck={false}
        className="flex-1 bg-transparent outline-none text-base"
        style={{ color: "var(--app-primary)" }}
      />
    </div>
  );
}
