"use client";

import React, { createContext, useContext, useEffect, useState, useCallback } from "react";
import { supabase } from "./supabase";
import type { User, FlightLicense, AssessmentType } from "./types";

// ─── Types ───────────────────────────────────────────────────────────────────

interface AuthContextValue {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  isRestoring: boolean;
  error: string | null;
  setError: (e: string | null) => void;
  signUp: (name: string, email: string, password: string, inviteCode: string) => Promise<void>;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  sendPasswordReset: (email: string) => Promise<void>;
  changePassword: (newPassword: string) => Promise<void>;
  updateAssessmentType: (type: AssessmentType) => Promise<void>;
  updateFlightLicenses: (licenses: FlightLicense[]) => Promise<void>;
  resetSurveyData: () => Promise<void>;
  deleteAccount: () => Promise<void>;
  isGerman: boolean;
  setLanguage: (lang: "de" | "en" | "auto") => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}

// ─── Provider ────────────────────────────────────────────────────────────────

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser]               = useState<User | null>(null);
  const [isAuthenticated, setIsAuth]  = useState(false);
  const [isLoading, setIsLoading]     = useState(false);
  const [isRestoring, setIsRestoring] = useState(true);
  const [error, setError]             = useState<string | null>(null);

  // Detect browser language with optional override
  const [languageOverride, setLangOverride] = useState<"de" | "en" | null>(() => {
    if (typeof localStorage !== "undefined") {
      const v = localStorage.getItem("pm_language");
      return v === "de" || v === "en" ? v : null;
    }
    return null;
  });
  const isGerman = languageOverride != null
    ? languageOverride === "de"
    : typeof navigator !== "undefined" && navigator.language.startsWith("de");

  function setLanguage(lang: "de" | "en" | "auto") {
    if (lang === "auto") { localStorage.removeItem("pm_language"); setLangOverride(null); }
    else { localStorage.setItem("pm_language", lang); setLangOverride(lang as "de" | "en"); }
  }

  // ── Map Supabase user row → User ──────────────────────────────────────────
  function mapRow(row: Record<string, unknown>): User {
    const licenses = (row.flight_licenses as string[] | null)
      ?.map((l) => l as FlightLicense) ?? undefined;
    return {
      id:             row.id as string,
      name:           row.full_name as string,
      email:          row.email as string,
      assessmentType: (row.assessment_type as AssessmentType | null) ?? undefined,
      flightLicenses: licenses,
    };
  }

  // ── Restore session on mount ──────────────────────────────────────────────
  const restoreSession = useCallback(async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) { setIsRestoring(false); return; }

      const { data, error } = await supabase
        .from("users")
        .select("*")
        .eq("id", session.user.id)
        .single();

      if (!error && data) {
        setUser(mapRow(data as Record<string, unknown>));
        setIsAuth(true);
      } else {
        await supabase.auth.signOut();
      }
    } catch { /* ignore */ } finally {
      setIsRestoring(false);
    }
  }, []);

  useEffect(() => {
    restoreSession();
    // Listen for auth state changes (e.g. email confirmation callback)
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === "SIGNED_IN" && session) {
        // Fetch user row
        const { data } = await supabase
          .from("users")
          .select("*")
          .eq("id", session.user.id)
          .single();
        if (data) { setUser(mapRow(data as Record<string, unknown>)); setIsAuth(true); }
      }
      if (event === "SIGNED_OUT") { setUser(null); setIsAuth(false); }
    });
    return () => subscription.unsubscribe();
  }, [restoreSession]);

  // ── Helpers ───────────────────────────────────────────────────────────────

  async function createOrFetchUser(id: string, email: string, name: string) {
    const { data: existing } = await supabase
      .from("users").select("*").eq("id", id).single();
    if (existing) {
      setUser(mapRow(existing as Record<string, unknown>)); setIsAuth(true); return;
    }
    const newRow = { id, email, full_name: name || "Pilot", assessment_type: null, flight_licenses: null };
    await supabase.from("users").insert(newRow);
    setUser({ id, name: name || "Pilot", email }); setIsAuth(true);
  }

  // ── Sign up ───────────────────────────────────────────────────────────────

  async function signUp(name: string, email: string, password: string, inviteCode: string) {
    setIsLoading(true); setError(null);
    try {
      // Validate invite code
      const { data: invite } = await supabase
        .from("invite_codes")
        .select("id")
        .eq("code", inviteCode.toUpperCase().trim())
        .eq("email", email.toLowerCase().trim())
        .eq("used", false)
        .single();
      if (!invite) { setError("Invalid invite code or email not authorised."); return; }

      const { data, error: signUpError } = await supabase.auth.signUp({ email, password });
      if (signUpError) { setError(signUpError.message); return; }

      // Redeem invite code
      await supabase.from("invite_codes")
        .update({ used: true })
        .eq("code", inviteCode.toUpperCase().trim());

      if (data.session) {
        await createOrFetchUser(data.user!.id, email, name);
      }
      // else: email confirmation required — UI handles this
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setIsLoading(false);
    }
  }

  // ── Sign in ───────────────────────────────────────────────────────────────

  async function signIn(email: string, password: string) {
    setIsLoading(true); setError(null);
    try {
      const { data, error: signInError } = await supabase.auth.signInWithPassword({ email, password });
      if (signInError) { setError(signInError.message); return; }
      await createOrFetchUser(data.user.id, email, "");
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setIsLoading(false);
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  async function signOut() {
    await supabase.auth.signOut();
    setUser(null); setIsAuth(false);
    localStorage.removeItem("pm_session_id");
    localStorage.removeItem("pm_feedback_link");
    localStorage.removeItem("pm_analysis_result_v1");
    localStorage.removeItem("pm_interview_run_count");
    localStorage.removeItem("pm_interview_questions_v1");
    localStorage.removeItem("pm_self_responses");
    localStorage.removeItem("pm_privacy_accepted");
  }

  // ── Password reset ────────────────────────────────────────────────────────

  async function sendPasswordReset(email: string) {
    const redirectTo = `${window.location.origin}/PilotMirror/login`;
    const { error: err } = await supabase.auth.resetPasswordForEmail(email, { redirectTo });
    if (err) throw new Error(err.message);
  }

  async function changePassword(newPassword: string) {
    setIsLoading(true);
    try {
      const { error: err } = await supabase.auth.updateUser({ password: newPassword });
      if (err) throw new Error(err.message);
    } finally {
      setIsLoading(false);
    }
  }

  // ── Update assessment type ────────────────────────────────────────────────

  async function updateAssessmentType(type: AssessmentType) {
    if (!user) return;
    setUser({ ...user, assessmentType: type });
    await supabase.from("users").update({ assessment_type: type }).eq("id", user.id);
  }

  // ── Update flight licenses ────────────────────────────────────────────────

  async function updateFlightLicenses(licenses: FlightLicense[]) {
    if (!user) return;
    setUser({ ...user, flightLicenses: licenses });
    await supabase.from("users").update({ flight_licenses: licenses }).eq("id", user.id);
  }

  // ── Reset survey data ─────────────────────────────────────────────────────

  async function resetSurveyData() {
    if (!user) return;
    const sessionId = localStorage.getItem("pm_session_id");
    if (sessionId) {
      await supabase.from("self_responses").delete().eq("session_id", sessionId);
      await supabase.from("feedback_links").delete().eq("session_id", sessionId);
      await supabase.from("assessment_sessions").delete().eq("candidate_id", user.id);
    }
    ["pm_session_id","pm_feedback_link","pm_analysis_result_v1",
     "pm_interview_run_count","pm_interview_questions_v1","pm_self_responses"]
      .forEach((k) => localStorage.removeItem(k));
  }

  // ── Delete account ────────────────────────────────────────────────────────

  async function deleteAccount() {
    if (!user) return;
    await resetSurveyData();
    await supabase.from("users").delete().eq("id", user.id);
    signOut();
  }

  return (
    <AuthContext.Provider value={{
      user, isAuthenticated, isLoading, isRestoring, error, setError,
      signUp, signIn, signOut,
      sendPasswordReset, changePassword,
      updateAssessmentType, updateFlightLicenses,
      resetSurveyData, deleteAccount,
      isGerman, setLanguage,
    }}>
      {children}
    </AuthContext.Provider>
  );
}
