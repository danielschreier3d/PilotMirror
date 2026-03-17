import { createClient } from "@supabase/supabase-js";

export const SUPABASE_URL  = process.env.NEXT_PUBLIC_SUPABASE_URL!;
export const SUPABASE_ANON = process.env.NEXT_PUBLIC_SUPABASE_ANON!;

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
