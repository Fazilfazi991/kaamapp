"use client";

import { createBrowserClient } from "@supabase/ssr";
import { supabaseConfig } from "./env";

export function createBrowserSupabaseClient() {
  const { url, anonKey } = supabaseConfig();
  return createBrowserClient(url, anonKey);
}
