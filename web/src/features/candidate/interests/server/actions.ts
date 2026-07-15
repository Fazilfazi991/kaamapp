"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireRole } from "@/lib/auth/session";
import { routes } from "@/config/routes";
import { validateInterestTransition } from "@/features/candidate/interests/utils";
import type { CandidateInterestRow, InterestStatus } from "@/features/candidate/interests/types";

function safeError(message: string): never {
  throw new Error(message);
}

async function loadOwnedInterest(interestId: string) {
  const account = await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("interest_requests")
    .select("id,employer_id,company_id,candidate_id,message,status,created_at,updated_at")
    .eq("id", interestId)
    .eq("candidate_id", account.userId)
    .maybeSingle<CandidateInterestRow>();
  return { account, supabase, interest: data };
}

async function respondToInterest(formData: FormData, next: "accepted" | "rejected") {
  const interestId = String(formData.get("interestId") ?? "");
  if (!interestId) safeError("Interest request is missing.");
  const { account, supabase, interest } = await loadOwnedInterest(interestId);
  if (!interest) safeError("Interest request was not found.");
  const transition = validateInterestTransition(interest.status as InterestStatus, next);
  if (!transition.ok) safeError(transition.error);

  if (next === "accepted") {
    const { data: existingMatch } = await supabase
      .from("matches")
      .select("id")
      .eq("candidate_id", account.userId)
      .eq("company_id", interest.company_id)
      .maybeSingle<{ id: string }>();
    if (existingMatch) safeError("A match already exists for this employer.");
  }

  const { error } = await supabase
    .from("interest_requests")
    .update({ status: next })
    .eq("id", interest.id)
    .eq("candidate_id", account.userId)
    .eq("status", "pending");
  if (error) safeError(next === "accepted" ? "Could not accept this interest." : "Could not reject this interest.");

  if (next === "accepted") {
    const { data: match } = await supabase
      .from("matches")
      .select("id")
      .eq("interest_request_id", interest.id)
      .maybeSingle<{ id: string }>();
    if (!match) {
      console.warn("[CandidateInterest] accepted interest without resolvable match", { stage: "resolve_match" });
    }
  }

  revalidatePath(routes.candidateDashboard);
  revalidatePath(routes.candidateInterests);
  revalidatePath(routes.candidateMatches);
  revalidatePath(routes.candidateMessages);
  revalidatePath(routes.employerInterests);
  revalidatePath(routes.employerMatches);
  revalidatePath(routes.employerMessages);
  redirect(next === "accepted" ? routes.candidateMatches : routes.candidateInterests);
}

export async function acceptInterest(formData: FormData) {
  await respondToInterest(formData, "accepted");
}

export async function rejectInterest(formData: FormData) {
  await respondToInterest(formData, "rejected");
}

export async function revealContactForMatch(formData: FormData) {
  const matchId = String(formData.get("matchId") ?? "");
  if (!matchId) safeError("Match is missing.");
  await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("reveal_candidate_contact", { target_match_id: matchId });
  if (error) safeError("Could not reveal contact for this match.");
  revalidatePath(routes.candidateMatches);
  revalidatePath(routes.employerMatches);
}
