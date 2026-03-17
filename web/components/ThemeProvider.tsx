"use client";

import { useEffect } from "react";

export default function ThemeProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    // Read saved preference or default to dark
    const saved = localStorage.getItem("pm_appearance") ?? "dark";
    const html = document.documentElement;

    if (saved === "dark") {
      html.classList.add("dark");
    } else if (saved === "light") {
      html.classList.remove("dark");
    } else {
      // "system"
      const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
      if (prefersDark) html.classList.add("dark");
      else html.classList.remove("dark");
    }
  }, []);

  return <>{children}</>;
}
