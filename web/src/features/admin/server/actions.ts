"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/features/admin/auth/require-admin";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import {
  type AdminActionState,
  canApproveEmployerDocument,
  canBlockUser,
  canRequestEmployerDocumentResubmission,
  getEmployerCompanyVerificationState,
  isAllowedCandidateDocumentApproval,
  isEmployerCompanyProfileComplete,
  safeActionResult,
  validatePublicReason,
} from "@/features/admin/validation/review";
import type { CandidateDocumentVersionRow, EmployerCompanyAdminRow, EmployerDocumentAdminRow } from "@/features/admin/types";
import type { CandidateVerificationStatus } from "@/features/admin/verification-status";

function fail(message: string): never {
  throw new Error(message);
}

async function updateCandidateVerification({
  candidateId,
  nextStatus,
  internalNotes,
  candidateMessage,
}: {
  candidateId: string;
  nextStatus: CandidateVerificationStatus;
  internalNotes: string | null;
  candidateMessage: string | null;
}): Promise<AdminActionState> {
  await requireAdmin();
  if (!candidateId) fail("Candidate is missing.");

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("review_candidate_manual_verification", {
    p_candidate_id: candidateId,
    p_next_status: nextStatus,
    p_internal_notes: internalNotes,
    p_candidate_message: candidateMessage,
  });
  if (error) return safeActionResult("Candidate verification could not be completed. No notification was queued.");

  revalidatePath("/admin/candidates");
  revalidatePath(`/admin/candidates/${candidateId}`);
  const result = (data ?? {}) as { already_processed?: boolean; push_queued?: boolean };
  if (result.already_processed) return safeActionResult("This verification action was already processed. No duplicate notification was created.", true);
  const actionLabel = nextStatus === "verified" ? "Candidate verified successfully." : nextStatus === "rejected" ? "Verification rejected." : "Reverification requested.";
  return safeActionResult(`${actionLabel} In-app notification created${result.push_queued ? " and push notification queued." : ". Push was not queued."}`, true);
}

export async function verifyCandidate(_previousState: AdminActionState, formData: FormData) {
  return updateCandidateVerification({
    candidateId: String(formData.get("candidateId") ?? ""),
    nextStatus: "verified",
    internalNotes: String(formData.get("internalNotes") ?? "").trim() || null,
    candidateMessage: null,
  });
}

export async function rejectCandidateVerification(_previousState: AdminActionState, formData: FormData) {
  const parsedReason = validatePublicReason(String(formData.get("candidateMessage") ?? ""));
  if (!parsedReason.ok) fail(parsedReason.error);
  return updateCandidateVerification({
    candidateId: String(formData.get("candidateId") ?? ""),
    nextStatus: "rejected",
    internalNotes: String(formData.get("internalNotes") ?? "").trim() || null,
    candidateMessage: parsedReason.reason,
  });
}

export async function requireCandidateReverification(_previousState: AdminActionState, formData: FormData) {
  const parsedReason = validatePublicReason(String(formData.get("candidateMessage") ?? ""));
  if (!parsedReason.ok) fail(parsedReason.error);
  return updateCandidateVerification({
    candidateId: String(formData.get("candidateId") ?? ""),
    nextStatus: "reverification_required",
    internalNotes: String(formData.get("internalNotes") ?? "").trim() || null,
    candidateMessage: parsedReason.reason,
  });
}

export async function approveCandidateDocument(formData: FormData) {
  await requireAdmin();
  const documentId = String(formData.get("documentId") ?? "");
  if (!documentId) fail("Document is missing.");

  const supabase = await createServerSupabaseClient();
  const { data: document } = await supabase
    .from("candidate_document_versions")
    .select("id,candidate_document_id,candidate_id,document_type,status,is_active,version_number")
    .eq("id", documentId)
    .maybeSingle<CandidateDocumentVersionRow>();

  if (!document) fail("Document was not found.");
  if (!isAllowedCandidateDocumentApproval(document.status, document.is_active)) {
    fail("Only active pending documents can be approved.");
  }

  const { error: reviewError } = await supabase.rpc("review_candidate_document", {
    p_document_version_id: document.id,
    p_action: "approved",
    p_public_reason: null,
    p_internal_notes: null,
  });
  if (reviewError) fail("Could not approve candidate document.");

  revalidatePath("/admin/candidate-documents");
  revalidatePath(`/admin/candidate-documents/${document.id}`);
  revalidatePath(`/admin/candidates/${document.candidate_id}`);
}

export async function rejectCandidateDocument(formData: FormData) {
  await requireAdmin();
  const documentId = String(formData.get("documentId") ?? "");
  const parsedReason = validatePublicReason(String(formData.get("reason") ?? ""));
  if (!documentId) fail("Document is missing.");
  if (!parsedReason.ok) fail(parsedReason.error);

  const supabase = await createServerSupabaseClient();
  const { data: document } = await supabase
    .from("candidate_document_versions")
    .select("id,candidate_id,document_type,status,is_active,version_number")
    .eq("id", documentId)
    .maybeSingle<CandidateDocumentVersionRow>();
  if (!document) fail("Document was not found.");
  if (!isAllowedCandidateDocumentApproval(document.status, document.is_active)) {
    fail("Only active pending documents can be rejected.");
  }

  const { error: reviewError } = await supabase.rpc("review_candidate_document", {
    p_document_version_id: document.id,
    p_action: "rejected",
    p_public_reason: parsedReason.reason,
    p_internal_notes: null,
  });
  if (reviewError) fail("Could not reject candidate document.");

  revalidatePath("/admin/candidate-documents");
  revalidatePath(`/admin/candidate-documents/${document.id}`);
  revalidatePath(`/admin/candidates/${document.candidate_id}`);
}

function revalidateEmployerDocumentReview(document: Pick<EmployerDocumentAdminRow, "id" | "company_id">) {
  revalidatePath("/admin");
  revalidatePath("/admin/employer-documents");
  revalidatePath(`/admin/employer-documents/${document.id}`);
  if (document.company_id) revalidatePath(`/admin/employers/${document.company_id}`);
}

export async function approveEmployerDocument(_previousState: AdminActionState, formData: FormData): Promise<AdminActionState> {
  await requireAdmin();
  const documentId = String(formData.get("documentId") ?? "");
  if (!documentId) return safeActionResult("Document is missing.");

  const supabase = await createServerSupabaseClient();
  const { data: document, error: loadError } = await supabase
    .from("verification_documents")
    .select("id,owner_id,company_id,document_type,status,bucket_id,file_path,created_at,updated_at")
    .eq("id", documentId)
    .maybeSingle<EmployerDocumentAdminRow>();
  if (loadError) return safeActionResult("Document could not be loaded. Please try again.");
  if (!document) return safeActionResult("Document was not found.");
  if (document.status === "approved") return safeActionResult("This document has already been approved.", true);
  if (!canApproveEmployerDocument(document)) return safeActionResult("Document is no longer pending review.");

  const { error } = await supabase
    .from("verification_documents")
    .update({ status: "approved" })
    .eq("id", document.id)
    .eq("status", "pending");
  if (error) return safeActionResult("Could not approve employer document. Please try again.");

  revalidateEmployerDocumentReview(document);
  return safeActionResult("Document approved.", true);
}

export async function rejectEmployerDocument(_previousState: AdminActionState, formData: FormData): Promise<AdminActionState> {
  await requireAdmin();
  const documentId = String(formData.get("documentId") ?? "");
  const parsedReason = validatePublicReason(String(formData.get("reason") ?? ""));
  if (!documentId) return safeActionResult("Document is missing.");
  if (!parsedReason.ok) return safeActionResult(parsedReason.error);

  const supabase = await createServerSupabaseClient();
  const { data: document, error: loadError } = await supabase
    .from("verification_documents")
    .select("id,owner_id,company_id,document_type,status,bucket_id,file_path,created_at,updated_at")
    .eq("id", documentId)
    .maybeSingle<EmployerDocumentAdminRow>();
  if (loadError) return safeActionResult("Document could not be loaded. Please try again.");
  if (!document) return safeActionResult("Document was not found.");
  if (document.status === "approved") return safeActionResult("Approved documents cannot be sent for resubmission.");
  if (!canRequestEmployerDocumentResubmission(document)) return safeActionResult("Document is no longer pending review.");

  const { error } = await supabase
    .from("verification_documents")
    .update({ status: "resubmission_requested" })
    .eq("id", document.id)
    .eq("status", "pending");
  if (error) return safeActionResult("Could not request resubmission. Please try again.");

  revalidateEmployerDocumentReview(document);
  return safeActionResult("Resubmission requested.", true);
}

export async function verifyEmployerCompany(_previousState: AdminActionState, formData: FormData): Promise<AdminActionState> {
  await requireAdmin();
  const companyId = String(formData.get("companyId") ?? "");
  if (!companyId) return safeActionResult("Company is missing.");

  const supabase = await createServerSupabaseClient();
  const { data: company, error: companyError } = await supabase
    .from("employer_companies")
    .select("id,owner_id,company_name,trade_license_number,industry,company_size,country,city,office_area,contact_person,contact_role,hiring_needs,website,logo_url,description,is_verified,status,created_at,updated_at")
    .eq("id", companyId)
    .maybeSingle<EmployerCompanyAdminRow>();
  if (companyError) return safeActionResult("Business verification data could not be loaded. Please try again.");
  if (!company) return safeActionResult("Company was not found.");
  if (company.is_verified) return safeActionResult("Business is already verified.", true);

  const profileComplete = isEmployerCompanyProfileComplete(company);
  const verificationState = getEmployerCompanyVerificationState({
    companyStatus: company.status,
    isVerified: company.is_verified,
    profileComplete,
    documentStatuses: {},
  });
  if (!verificationState.canApprove) {
    return safeActionResult(verificationState.reason);
  }

  const { error } = await supabase
    .from("employer_companies")
    .update({ status: "active", is_verified: true })
    .eq("id", companyId)
    .neq("status", "blocked");
  if (error) return safeActionResult("Could not verify business. Please try again.");

  revalidatePath("/admin");
  revalidatePath("/admin/employers");
  revalidatePath(`/admin/employers/${companyId}`);
  return safeActionResult("Business verified. Employer access was already active.", true);
}

export async function blockUser(formData: FormData) {
  const admin = await requireAdmin();
  const userId = String(formData.get("userId") ?? "");
  if (!canBlockUser({ actorId: admin.userId, targetId: userId, actorRole: admin.role })) {
    fail("Admins cannot block this account.");
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.from("profiles").update({ status: "blocked" }).eq("id", userId);
  if (error) fail("Could not block account.");
  revalidatePath("/admin/users");
  revalidatePath(`/admin/users/${userId}`);
}

export async function unblockUser(formData: FormData) {
  await requireAdmin();
  const userId = String(formData.get("userId") ?? "");
  if (!userId) fail("User is missing.");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.from("profiles").update({ status: "active" }).eq("id", userId).eq("status", "blocked");
  if (error) fail("Could not unblock account.");
  revalidatePath("/admin/users");
  revalidatePath(`/admin/users/${userId}`);
}
