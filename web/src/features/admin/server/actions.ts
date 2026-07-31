"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/features/admin/auth/require-admin";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import {
  type AdminActionState,
  canApproveEmployerDocument,
  canBlockUser,
  canRequestEmployerDocumentResubmission,
  documentStatusesByType,
  getEmployerCompanyApprovalState,
  isAllowedCandidateDocumentApproval,
  isEmployerCompanyProfileComplete,
  safeActionResult,
  validatePublicReason,
} from "@/features/admin/validation/review";
import type { CandidateDocumentVersionRow, EmployerCompanyAdminRow, EmployerDocumentAdminRow } from "@/features/admin/types";
import { candidateVerificationEligibility, type CandidateVerificationStatus } from "@/features/admin/verification-status";

function fail(message: string): never {
  throw new Error(message);
}

async function updateCandidateVerification({
  candidateId,
  nextStatus,
  notes,
  action,
}: {
  candidateId: string;
  nextStatus: CandidateVerificationStatus;
  notes: string | null;
  action: "candidate_verified" | "candidate_verification_rejected" | "candidate_reverification_required";
}) {
  const admin = await requireAdmin();
  if (!candidateId) fail("Candidate is missing.");

  const supabase = await createServerSupabaseClient();
  const [{ data: candidate }, { data: documents }] = await Promise.all([
    supabase
      .from("candidate_profiles")
      .select("id,verification_status,profile_photo_url,nationality,current_city,preferred_city,job_categories,headline,availability")
      .eq("id", candidateId)
      .maybeSingle(),
    supabase
      .from("candidate_documents")
      .select("passport_status")
      .eq("candidate_id", candidateId)
      .maybeSingle(),
  ]);
  const { data: account } = await supabase.from("profiles").select("status").eq("id", candidateId).maybeSingle();
  if (!candidate) fail("Candidate profile was not found.");

  if (nextStatus === "verified") {
    const profileCompletion = [
      candidate.nationality,
      candidate.current_city,
      candidate.preferred_city,
      candidate.headline,
      candidate.availability,
    ].every((value) => Boolean(value?.trim())) && (candidate.job_categories?.length ?? 0) > 0 ? 100 : 0;
    const eligibility = candidateVerificationEligibility({
      accountStatus: account?.status,
      profileCompletion,
      passportStatus: documents?.passport_status,
    });
    if (!eligibility.canVerify) fail(`Candidate cannot be verified yet: ${eligibility.blockers.join(" ")}`);
  }

  const now = new Date().toISOString();
  const { error: updateError } = await supabase
    .from("candidate_profiles")
    .update({
      verification_status: nextStatus,
      verified_by: admin.userId,
      verified_at: nextStatus === "verified" ? now : null,
      verification_notes: notes,
      verification_updated_at: now,
    })
    .eq("id", candidateId);
  if (updateError) fail("Could not update candidate manual verification.");

  const { error: auditError } = await supabase.from("candidate_verification_audit_events").insert({
    candidate_id: candidateId,
    admin_id: admin.userId,
    previous_status: candidate.verification_status ?? "pending_verification",
    new_status: nextStatus,
    action,
    notes,
  });
  if (auditError) fail("Verification status was updated, but its audit event could not be recorded.");

  revalidatePath("/admin/candidates");
  revalidatePath(`/admin/candidates/${candidateId}`);
}

export async function verifyCandidate(formData: FormData) {
  const notes = String(formData.get("notes") ?? "").trim() || null;
  await updateCandidateVerification({
    candidateId: String(formData.get("candidateId") ?? ""),
    nextStatus: "verified",
    notes,
    action: "candidate_verified",
  });
}

export async function rejectCandidateVerification(formData: FormData) {
  const parsedReason = validatePublicReason(String(formData.get("reason") ?? ""));
  if (!parsedReason.ok) fail(parsedReason.error);
  await updateCandidateVerification({
    candidateId: String(formData.get("candidateId") ?? ""),
    nextStatus: "rejected",
    notes: parsedReason.reason,
    action: "candidate_verification_rejected",
  });
}

export async function requireCandidateReverification(formData: FormData) {
  const parsedReason = validatePublicReason(String(formData.get("reason") ?? ""));
  if (!parsedReason.ok) fail(parsedReason.error);
  await updateCandidateVerification({
    candidateId: String(formData.get("candidateId") ?? ""),
    nextStatus: "reverification_required",
    notes: parsedReason.reason,
    action: "candidate_reverification_required",
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

  const statusField = document.document_type === "passport" ? "passport_status" : "visa_status";
  const verifiedField = document.document_type === "passport" ? "passport_verified" : "visa_verified";
  const verifiedAtField = document.document_type === "passport" ? "passport_verified_at" : "visa_verified_at";
  const versionField = document.document_type === "passport" ? "passport_version" : "visa_version";

  const { error: documentError } = await supabase
    .from("candidate_document_versions")
    .update({ status: "verified", verified_at: new Date().toISOString() })
    .eq("id", document.id)
    .eq("status", "pending_verification")
    .eq("is_active", true);
  if (documentError) fail("Could not approve candidate document.");

  const { error: summaryError } = await supabase
    .from("candidate_documents")
    .update({
      [statusField]: "verified",
      [verifiedField]: true,
      [verifiedAtField]: new Date().toISOString(),
    })
    .eq("candidate_id", document.candidate_id)
    .eq(versionField, document.version_number);
  if (summaryError) fail("Could not update candidate document status.");

  await supabase.from("candidate_document_notifications").insert({
    candidate_id: document.candidate_id,
    document_type: document.document_type,
    notification_type: "document_approved",
    title: "Document approved",
    body: "Your document has been approved by Kaam.",
  });

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

  const statusField = document.document_type === "passport" ? "passport_status" : "visa_status";
  const versionField = document.document_type === "passport" ? "passport_version" : "visa_version";

  const { error } = await supabase
    .from("candidate_document_versions")
    .update({ status: "rejected" })
    .eq("id", document.id)
    .eq("status", "pending_verification")
    .eq("is_active", true);
  if (error) fail("Could not reject candidate document.");

  await supabase
    .from("candidate_documents")
    .update({ [statusField]: "rejected" })
    .eq("candidate_id", document.candidate_id)
    .eq(versionField, document.version_number);

  await supabase.from("candidate_document_notifications").insert({
    candidate_id: document.candidate_id,
    document_type: document.document_type,
    notification_type: "document_rejected",
    title: "Document needs review",
    body: parsedReason.reason,
  });

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

export async function approveEmployerCompany(_previousState: AdminActionState, formData: FormData): Promise<AdminActionState> {
  await requireAdmin();
  const companyId = String(formData.get("companyId") ?? "");
  if (!companyId) return safeActionResult("Company is missing.");

  const supabase = await createServerSupabaseClient();
  const [{ data: company, error: companyError }, { data: documents, error: documentError }] = await Promise.all([
    supabase
      .from("employer_companies")
      .select("id,owner_id,company_name,trade_license_number,industry,company_size,country,city,office_area,contact_person,contact_role,hiring_needs,website,logo_url,description,is_verified,status,created_at,updated_at")
      .eq("id", companyId)
      .maybeSingle<EmployerCompanyAdminRow>(),
    supabase.from("verification_documents").select("document_type,status").eq("company_id", companyId),
  ]);
  if (companyError || documentError) return safeActionResult("Company review data could not be loaded. Please try again.");
  if (!company) return safeActionResult("Company was not found.");
  if (company.is_verified) return safeActionResult("Company is already approved.", true);

  const statusByType = documentStatusesByType(documents ?? []);
  const profileComplete = isEmployerCompanyProfileComplete(company);
  const approvalState = getEmployerCompanyApprovalState({
    companyStatus: company.status,
    isVerified: company.is_verified,
    profileComplete,
    documentStatuses: statusByType,
  });
  if (!approvalState.canApprove) {
    return safeActionResult(approvalState.reason);
  }

  const { error } = await supabase
    .from("employer_companies")
    .update({ status: "active", is_verified: true })
    .eq("id", companyId)
    .neq("status", "blocked");
  if (error) return safeActionResult("Could not approve company. Please try again.");

  revalidatePath("/admin");
  revalidatePath("/admin/employers");
  revalidatePath(`/admin/employers/${companyId}`);
  return safeActionResult("Company approved.", true);
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
