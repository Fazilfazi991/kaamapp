import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireRole } from "@/lib/auth/session";
import type { CandidateInterestRow, CandidateMatchRow } from "@/features/candidate/interests/types";

const INTEREST_SELECT =
  "id,employer_id,company_id,candidate_id,message,status,created_at,updated_at,employer_companies(id,company_name,industry,city,country,logo_url,description,is_verified,status)";

export async function loadCandidateInterests() {
  const account = await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("interest_requests")
    .select(INTEREST_SELECT)
    .eq("candidate_id", account.userId)
    .order("created_at", { ascending: false })
    .returns<CandidateInterestRow[]>();
  return { interests: data ?? [], error: error ? "Could not load employer interests." : null };
}

export async function loadCandidateInterest(interestId: string) {
  const account = await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("interest_requests")
    .select(INTEREST_SELECT)
    .eq("id", interestId)
    .eq("candidate_id", account.userId)
    .maybeSingle<CandidateInterestRow>();
  return data;
}

export async function loadCandidateMatches() {
  await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("candidate_matches_with_access");
  return { matches: (data ?? []) as CandidateMatchRow[], error: error ? "Could not load matches." : null };
}

export async function loadCandidateDashboardCounts() {
  const account = await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const [{ count: pending }, { count: accepted }, { count: matches }, { count: unread }] = await Promise.all([
    supabase
      .from("interest_requests")
      .select("*", { count: "exact", head: true })
      .eq("candidate_id", account.userId)
      .eq("status", "pending"),
    supabase
      .from("interest_requests")
      .select("*", { count: "exact", head: true })
      .eq("candidate_id", account.userId)
      .eq("status", "accepted"),
    supabase.from("matches").select("*", { count: "exact", head: true }).eq("candidate_id", account.userId),
    supabase
      .from("chat_messages")
      .select("id,matches!inner(candidate_id)", { count: "exact", head: true })
      .eq("matches.candidate_id", account.userId)
      .neq("sender_id", account.userId)
      .eq("is_read", false),
  ]);
  return {
    pendingInterests: pending ?? 0,
    acceptedInterests: accepted ?? 0,
    matches: matches ?? 0,
    unreadMessages: unread ?? 0,
  };
}
