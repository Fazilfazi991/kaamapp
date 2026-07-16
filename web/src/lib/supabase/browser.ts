"use client";

import { createBrowserClient } from "@supabase/ssr";
import { requireSupabaseConfig } from "./env";

export function createBrowserSupabaseClient() {
  const { url, anonKey } = requireSupabaseConfig();
  return createBrowserClient(url, anonKey);
}
