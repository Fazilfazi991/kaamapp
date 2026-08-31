import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { getAuthenticatedProfile } from "@/lib/auth/session";
import { isBlockedStatus } from "@/lib/auth/routing";
import { routes } from "@/config/routes";
import type { ChatMessageRow, ConversationAccess, ConversationSummary } from "@/features/messaging/types";
import type { UserRole } from "@/types/domain";

type CandidateInboxMatch = {
  match_id: string;
  company_name: string | null;
  role: string | null;
  location: string | null;
  matched_at: string;
  chat_enabled: boolean;
};

type EmployerInboxMatch = {
  match_id: string;
  candidate_id: string;
  display_name: string | null;
  role: string | null;
  location: string | null;
  matched_at: string;
  chat_enabled: boolean;
};

type InboxMessage = Pick<ChatMessageRow, "match_id" | "sender_id" | "body" | "is_read" | "created_at">;

function logPreviewTiming(event: string, timing: Record<string, number | string>) {
  if (process.env.VERCEL_ENV === "preview") {
    console.info(JSON.stringify({ event, ...timing }));
  }
}

export function buildConversationSummaries(
  role: "candidate" | "employer",
  userId: string,
  matches: CandidateInboxMatch[] | EmployerInboxMatch[],
  messages: InboxMessage[],
): ConversationSummary[] {
  const messageState = new Map<string, { latest: InboxMessage | null; unreadCount: number }>();

  for (const message of messages) {
    const state = messageState.get(message.match_id) ?? { latest: null, unreadCount: 0 };
    if (!state.latest || message.created_at > state.latest.created_at) state.latest = message;
    if (message.sender_id !== userId && message.is_read === false) state.unreadCount += 1;
    messageState.set(message.match_id, state);
  }

  return matches
    .map((match) => {
      const state = messageState.get(match.match_id);
      const candidateMatch = match as CandidateInboxMatch;
      const employerMatch = match as EmployerInboxMatch;
      const title = role === "candidate"
        ? candidateMatch.company_name || "Matched company"
        : employerMatch.display_name || `Candidate #${employerMatch.candidate_id.slice(0, 8)}`;
      const subtitle = role === "candidate"
        ? [candidateMatch.role, candidateMatch.location].filter(Boolean).join(" - ")
        : [employerMatch.role, employerMatch.location].filter(Boolean).join(" - ");

      return {
        matchId: match.match_id,
        title,
        subtitle,
        href: role === "candidate" ? `/candidate/messages/${match.match_id}` : `/employer/messages/${match.match_id}`,
        chatEnabled: match.chat_enabled === true,
        lastMessage: state?.latest?.body ?? "No messages yet.",
        lastMessageAt: state?.latest?.created_at ?? null,
        unreadCount: state?.unreadCount ?? 0,
      };
    })
    .sort((a, b) => (b.lastMessageAt ?? "").localeCompare(a.lastMessageAt ?? ""));
}

async function requireMessagingAccount() {
  const { user, profile } = await getAuthenticatedProfile();
  if (!user) redirect(routes.login);
  if (isBlockedStatus(profile?.status)) redirect(routes.accountBlocked);
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
  const startedAt = performance.now();
  const account = await requireMessagingAccount();
  const accountAt = performance.now();
  const supabase = await createServerSupabaseClient();
  const pageSize = 50;
  const from = Math.max(0, page - 1) * pageSize;
  const to = from + pageSize - 1;
  const [matchResult, enabledResult, messageResult] = await Promise.all([
    supabase
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
      }>(),
    supabase.rpc("match_chat_enabled", { target_match_id: matchId }),
    supabase
      .from("chat_messages")
      .select("id,match_id,sender_id,body,is_read,created_at")
      .eq("match_id", matchId)
      .order("created_at", { ascending: false })
      .range(from, to)
      .returns<ChatMessageRow[]>(),
  ]);
  const parallelReadsAt = performance.now();

  const match = matchResult.data;
  if (!match) return null;
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
  const participantAt = performance.now();
  const access: ConversationAccess = {
    userId: account.userId,
    role: account.role,
    matchId,
    chatEnabled: enabledResult.data === true,
    title,
    subtitle,
  };
  const { data: newestRows, error } = messageResult;

  if (!error) {
    await supabase
      .from("chat_messages")
      .update({ is_read: true })
      .eq("match_id", matchId)
      .neq("sender_id", access.userId)
      .eq("is_read", false);
  }
  const markReadAt = performance.now();

  logPreviewTiming("messaging.conversation.loader", {
    role: account.role,
    authAccountMs: Math.round(accountAt - startedAt),
    parallelReadsMs: Math.round(parallelReadsAt - accountAt),
    participantMs: Math.round(participantAt - parallelReadsAt),
    markReadMs: Math.round(markReadAt - participantAt),
    totalMs: Math.round(markReadAt - startedAt),
  });

  return {
    access,
    messages: (newestRows ?? []).reverse(),
    pageSize,
    page,
    error: error ? "Could not load messages." : null,
  };
}

export async function loadConversationSummaries(role: "candidate" | "employer") {
  const startedAt = performance.now();
  const account = await requireMessagingAccount();
  const accountAt = performance.now();
  if (account.role !== role) redirect(role === "candidate" ? routes.candidateDashboard : routes.employerDashboard);
  const supabase = await createServerSupabaseClient();
  const rpcName = role === "candidate" ? "candidate_matches_with_access" : "employer_matches_with_contact";
  const { data: matches } = await supabase.rpc(rpcName);
  const matchesAt = performance.now();
  const inboxMatches = (matches ?? []) as CandidateInboxMatch[] | EmployerInboxMatch[];
  if (!inboxMatches.length) {
    logPreviewTiming("messaging.inbox.loader", {
      role,
      conversations: 0,
      authAccountMs: Math.round(accountAt - startedAt),
      matchesMs: Math.round(matchesAt - accountAt),
      messagesMs: 0,
      aggregateMs: 0,
      totalMs: Math.round(matchesAt - startedAt),
    });
    return [];
  }

  const matchIds = inboxMatches.map((match) => match.match_id);
  const { data: messages } = await supabase
    .from("chat_messages")
    .select("match_id,sender_id,body,is_read,created_at")
    .in("match_id", matchIds)
    .returns<InboxMessage[]>();
  const messagesAt = performance.now();

  const summaries = buildConversationSummaries(role, account.userId, inboxMatches, messages ?? []);
  const completedAt = performance.now();
  logPreviewTiming("messaging.inbox.loader", {
    role,
    conversations: inboxMatches.length,
    authAccountMs: Math.round(accountAt - startedAt),
    matchesMs: Math.round(matchesAt - accountAt),
    messagesMs: Math.round(messagesAt - matchesAt),
    aggregateMs: Math.round(completedAt - messagesAt),
    totalMs: Math.round(completedAt - startedAt),
  });

  return summaries;
}
