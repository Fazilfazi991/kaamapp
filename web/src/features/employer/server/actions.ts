"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { routes } from "@/config/routes";
import { requireEmployerCompany } from "./access";

function safeError(message: string): never {
  throw new Error(message);
}

async function visibleCandidate(candidateId: string) {
  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("public_candidate_search")
    .select("id,headline")
    .eq("id", candidateId)
    .maybeSingle<{ id: string; headline: string | null }>();
  return data;
}

export async function shortlistCandidate(formData: FormData) {
  const candidateId = String(formData.get("candidateId") ?? "");
  if (!candidateId) safeError("Candidate is missing.");
  const { userId } = await requireEmployerCompany();
  const candidate = await visibleCandidate(candidateId);
  if (!candidate) safeError("This candidate is no longer visible.");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase
    .from("saved_candidates")
    .upsert({ employer_id: userId, candidate_id: candidateId }, { onConflict: "employer_id,candidate_id" });
  if (error) safeError("Could not shortlist this candidate.");
  revalidatePath(routes.employerSearch);
  revalidatePath(routes.employerShortlist);
}

export async function removeShortlistCandidate(formData: FormData) {
  const candidateId = String(formData.get("candidateId") ?? "");
  if (!candidateId) safeError("Candidate is missing.");
  const { userId } = await requireEmployerCompany();
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase
    .from("saved_candidates")
    .delete()
    .eq("employer_id", userId)
    .eq("candidate_id", candidateId);
  if (error) safeError("Could not remove this candidate.");
  revalidatePath(routes.employerSearch);
  revalidatePath(routes.employerShortlist);
}

export async function sendInterest(formData: FormData) {
  const candidateId = String(formData.get("candidateId") ?? "");
  if (!candidateId) safeError("Candidate is missing.");
  const access = await requireEmployerCompany();
  if (candidateId === access.userId) safeError("You cannot send interest to your own account.");
  const candidate = await visibleCandidate(candidateId);
  if (!candidate) safeError("This candidate is no longer visible.");

  const supabase = await createServerSupabaseClient();
  const { data: existingMatch } = await supabase
    .from("matches")
    .select("id")
    .eq("employer_id", access.userId)
    .eq("candidate_id", candidateId)
    .maybeSingle<{ id: string }>();
  if (existingMatch) safeError("You are already matched with this candidate.");

  const { data: existingInterest } = await supabase
    .from("interest_requests")
    .select("id,status")
    .eq("employer_id", access.userId)
    .eq("candidate_id", candidateId)
    .maybeSingle<{ id: string; status: string }>();
  if (existingInterest && existingInterest.status !== "withdrawn") {
    safeError("An active interest request already exists for this candidate.");
  }

  const message = [
    "Employer web interest request.",
    "",
    `Role: ${candidate.headline ?? "Role shared after connection"}`,
    "Salary: Not shared",
    `Location: ${access.company.city ?? "Location not shared"}`,
    "Hours: Not shared",
    "Accommodation: Not shared",
    "Transport: Not shared",
    "Visa support: Not shared",
  ].join("\n");

  const { error } = await supabase.from("interest_requests").insert({
    employer_id: access.userId,
    company_id: access.company.id,
    candidate_id: candidateId,
    message,
  });
  if (error) safeError("Could not send interest to this candidate.");
  revalidatePath(routes.employerSearch);
  revalidatePath(routes.employerShortlist);
  revalidatePath(routes.employerInterests);
  redirect(routes.employerInterests);
}

export async function withdrawInterest(formData: FormData) {
  const interestId = String(formData.get("interestId") ?? "");
  if (!interestId) safeError("Interest request is missing.");
  const access = await requireEmployerCompany();
  const supabase = await createServerSupabaseClient();
  const { data: interest } = await supabase
    .from("interest_requests")
    .select("id,status")
    .eq("id", interestId)
    .eq("employer_id", access.userId)
    .maybeSingle<{ id: string; status: string }>();
  if (!interest) safeError("Interest request was not found.");
  if (interest.status !== "pending") safeError("Only pending interest requests can be withdrawn.");
  const { error } = await supabase
    .from("interest_requests")
    .update({ status: "withdrawn" })
    .eq("id", interestId)
    .eq("employer_id", access.userId);
  if (error) safeError("Could not withdraw this interest.");
  revalidatePath(routes.employerInterests);
}
