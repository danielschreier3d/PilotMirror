import { createClient } from "@supabase/supabase-js";

export const SUPABASE_URL  = "https://outsherttkwwuvihpkzn.supabase.co";
export const SUPABASE_ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im91dHNoZXJ0dGt3d3V2aWhwa3puIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyODE4NzgsImV4cCI6MjA4ODg1Nzg3OH0.KRFm5YghZPysybdTKtQRUX2Mr6pOKgyWgJ1gOnc-9as";

// Single shared client instance
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON, {
  auth: {
    persistSession: true,
    storageKey: "pm_sb_session",
    autoRefreshToken: true,
  },
});

export const ANALYZE_URL   = `${SUPABASE_URL}/functions/v1/analyze`;
export const HINT_URL      = `${SUPABASE_URL}/functions/v1/interview-hint`;
