import "server-only";

import { createClient } from "@supabase/supabase-js";
import { requireSupabaseConfig, requireSupabaseServiceRoleKey } from "./env";

/** Server-only client for webhook fulfillment. Never import this from client code. */
export function createServiceSupabaseClient() {
  const { url } = requireSupabaseConfig();
  const serviceRoleKey = requireSupabaseServiceRoleKey();

  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
