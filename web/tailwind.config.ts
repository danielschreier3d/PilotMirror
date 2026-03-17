import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        // Semantic design tokens matching iOS AppColors.swift
        "app-bg":       "var(--app-bg)",
        "app-card":     "var(--app-card)",
        "app-input":    "var(--app-input)",
        "app-border":   "var(--app-border)",
        "app-primary":  "var(--app-primary)",
        "app-secondary":"var(--app-secondary)",
        "app-tertiary": "var(--app-tertiary)",
        blue: { DEFAULT: "#4A9EF8", 400: "#6BB3FA", 600: "#2B82E0" },
        purple: { DEFAULT: "#6B5EE4" },
        green: { DEFAULT: "#34C759" },
        red:   { DEFAULT: "#FF6B6B" },
        orange:{ DEFAULT: "#FF9F0A" },
      },
      fontFamily: {
        sans: ["-apple-system", "BlinkMacSystemFont", "Segoe UI", "Roboto", "sans-serif"],
      },
      borderRadius: {
        "2xl": "1rem",
        "3xl": "1.25rem",
      },
    },
  },
  plugins: [],
};
export default config;
