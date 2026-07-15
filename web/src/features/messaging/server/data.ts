import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { getAuthenticatedProfile } from "@/lib/auth/session";
import { routes } from "@/config/routes";
import type { ChatMessageRow, ConversationAccess, ConversationSummary } from "@/features/messaging/types";
import type { UserRole } from "@/types/domain";

async function requireMessagingAccount() {
  const { user, profile } = await getAuthenticatedProfile();
  if (!user) redirect(routes.login);
  if (profile?.role !== "candidate" && profile?.role !== "employer") redirect(routes.accountConflict);
  return { userId: user.id, role: profile.role as UserRole };
}

export async function resolveConversationAccess(matchId: string): Promise<ConversationAccess | null> {
  const account = await requireMessagingAccount();
  const supabase = await createServerSupabaseClient();
  const { data: match } = await supabase
    .from("matches")
    .select("id,candidate_id,employer_id,company_id,employer_companies(company_name,industry,city)")
    .eq("id", matchId)
    .or(`candidate_id.eq.${account.userId},employer_id.eq.${account.userId}`)
    .maybeSingle<{
      id: string;
      candidate_id: string;
      employer_id: string;
      company_id: string;
      employer_companies?: { company_name: string | null; industry: string | null; city: string | null } | null;
    }>();
  if (!match) return null;
  const { data: enabled } = await supabase.rpc("match_chat_enabled", { target_match_id: matchId });
  const chatEnabled = enabled === true;
  let title = match.employer_companies?.company_name ?? "Matched company";
  let subtitle = [match.employer_companies?.industry, match.employer_companies?.city].filter(Boolean).join(" - ");
  if (account.role === "employer") {
    const { data: candidate } = await supabase
      .from("public_candidate_search")
      .select("full_name,headline,current_city")
      .eq("id", match.candidate_id)
      .maybeSingle<{ full_name: string | null; headline: string | null; current_city: string | null }>();
    title = candidate?.full_name || `Candidate #${match.candidate_id.slice(0, 8)}`;
    subtitle = [candidate?.headline, candidate?.current_city].filter(Boolean).join(" - ");
  }
  return { userId: account.userId, role: account.role, matchId, chatEnabled, title, subtitle };
}

export async function loadConversation(matchId: string, page = 1) {
  const access = await resolveConversationAccess(matchId);
  if (!access) return null;
  const supabase = await createServerSupabaseClient();
  const pageSize = 50;
  const from = Math.max(0, page - 1) * pageSize;
  const to = from + pageSize - 1;
  const { data: newestRows, error } = await supabase
    .from("chat_messages")
    .select("id,match_id,sender_id,body,is_read,created_at")
    .eq("match_id", matchId)
    .order("created_at", { ascending: false })
    .range(from, to)
    .returns<ChatMessageRow[]>();

  if (!error) {
    await supabase
      .from("chat_messages")
      .update({ is_read: true })
      .eq("match_id", matchId)
      .neq("sender_id", access.userId)
      .eq("is_read", false);
  }

  return {
    access,
    messages: (newestRows ?? []).reverse(),
    pageSize,
    page,
    error: error ? "Could not load messages." : null,
  };
}

export async function loadConversationSummaries(role: "candidate" | "employer") {
  const account = await requireMessagingAccount();
  if (account.role !== role) redirect(role === "candidate" ? routes.candidateDashboard : routes.employerDashboard);
  const supabase = await createServerSupabaseClient();
  const matchColumn = role === "candidate" ? "candidate_id" : "employer_id";
  const { data: matches } = await supabase
    .from("matches")
    .select("id,candidate_id,employer_id,created_at,employer_companies(company_name,industry,city)")
    .eq(matchColumn, account.userId)
    .order("created_at", { ascending: false })
    .returns<
      Array<{
        id: string;
        candidate_id: string;
        employer_id: string;
        created_at: string;
        employer_companies?: { company_name: string | null; industry: string | null; city: string | null } | null;
      }>
    >();
  const summaries: ConversationSummary[] = [];
  for (const match of matches ?? []) {
    const [{ data: enabled }, { data: latest }, { count: unread }] = await Promise.all([
      supabase.rpc("match_chat_enabled", { target_match_id: match.id }),
      supabase
        .from("chat_messages")
        .select("body,created_at")
        .eq("match_id", match.id)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle<{ body: string; created_at: string }>(),
      supabase
        .from("chat_messages")
        .select("id", { count: "exact", head: true })
        .eq("match_id", match.id)
        .neq("sender_id", account.userId)
        .eq("is_read", false),
    ]);
    let title = match.employer_companies?.company_name ?? "Matched company";
    let subtitle = [match.employer_companies?.industry, match.employer_companies?.city].filter(Boolean).join(" - ");
    if (role === "employer") {
      const { data: candidate } = await supabase
        .from("public_candidate_search")
        .select("full_name,headline,current_city")
        .eq("id", match.candidate_id)
        .maybeSingle<{ full_name: string | null; headline: string | null; current_city: string | null }>();
      title = candidate?.full_name || `Candidate #${match.candidate_id.slice(0, 8)}`;
      subtitle = [candidate?.headline, candidate?.current_city].filter(Boolean).join(" - ");
    }
    summaries.push({
      matchId: match.id,
      title,
      subtitle,
      href: role === "candidate" ? `/candidate/messages/${match.id}` : `/employer/messages/${match.id}`,
      chatEnabled: enabled === true,
      lastMessage: latest?.body ?? "No messages yet.",
      lastMessageAt: latest?.created_at ?? null,
      unreadCount: unread ?? 0,
    });
  }
  return summaries.sort((a, b) => (b.lastMessageAt ?? "").localeCompare(a.lastMessageAt ?? ""));
}
