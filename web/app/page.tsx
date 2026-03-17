"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";

export default function RootPage() {
  const { isAuthenticated, isRestoring, user } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (isRestoring) return;

    if (!isAuthenticated) {
      router.replace("/login");
      return;
    }

    const privacyAccepted = localStorage.getItem("pm_privacy_accepted") === "true";
    if (!privacyAccepted) { router.replace("/privacy"); return; }

    if (!user?.assessmentType) { router.replace("/setup/assessment"); return; }
    if (!user?.flightLicenses)  { router.replace("/setup/licenses");   return; }

    router.replace("/dashboard");
  }, [isAuthenticated, isRestoring, user, router]);

  // Show loading state while restoring
  return (
    <div className="flex items-center justify-center min-h-svh" style={{ background: "var(--app-bg)" }}>
      <div className="flex flex-col items-center gap-4">
        <div className="text-4xl">✈️</div>
        <div className="spinner" />
      </div>
    </div>
  );
}
