import { employerRequiredDocumentTypes } from "@/features/employer/profile/completion";
import type { CandidateDocumentStatus, EmployerCompanyAdminRow, EmployerDocumentAdminRow, EmployerDocumentStatus } from "@/features/admin/types";

export const candidateDocumentStatuses = [
  "not_uploaded",
  "pending_verification",
  "verified",
  "rejected",
  "expired",
  "archived",
] as const;

export const employerDocumentStatuses = [
  "pending",
  "approved",
  "rejected",
  "resubmission_requested",
] as const;

export function statusTone(status?: string | null): "success" | "warning" | "neutral" | "danger" {
  if (!status) return "neutral";
  if (["verified", "approved", "active"].includes(status)) return "success";
  if (["pending", "pending_verification", "draft", "paused", "resubmission_requested"].includes(status)) {
    return "warning";
  }
  if (["rejected", "expired", "blocked", "archived"].includes(status)) return "danger";
  return "neutral";
}

export function statusLabel(status?: string | null) {
  return (status || "unknown").replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

export function isAllowedCandidateDocumentApproval(status: CandidateDocumentStatus, isActive: boolean) {
  return isActive && status === "pending_verification";
}

export type AdminActionState = {
  ok: boolean;
  message: string;
};

export const initialAdminActionState: AdminActionState = { ok: false, message: "" };

export function safeActionResult(message: string, ok = false): AdminActionState {
  return { ok, message };
}

export function isAllowedEmployerDocumentApproval(status: EmployerDocumentStatus) {
  return status === "pending";
}

export function canApproveEmployerDocument(document?: Pick<EmployerDocumentAdminRow, "status"> | null) {
  return document?.status === "pending";
}

export function canRequestEmployerDocumentResubmission(document?: Pick<EmployerDocumentAdminRow, "status"> | null) {
  return document?.status === "pending";
}

export function getEmployerDocumentReviewState(document: Pick<EmployerDocumentAdminRow, "status">) {
  const canApprove = canApproveEmployerDocument(document);
  const canRequestResubmission = canRequestEmployerDocumentResubmission(document);

  if (document.status === "approved") {
    return {
      canApprove,
      canRequestResubmission,
      message: "This document has been approved. No further review action is available.",
    };
  }

  if (["rejected", "resubmission_requested"].includes(document.status)) {
    return {
      canApprove,
      canRequestResubmission,
      message: "This document is not pending review. Wait for a new employer submission before taking action.",
    };
  }

  if (!canApprove && !canRequestResubmission) {
    return {
      canApprove,
      canRequestResubmission,
      message: "This document is not eligible for review.",
    };
  }

  return {
    canApprove,
    canRequestResubmission,
    message: "Pending review.",
  };
}

export function validatePublicReason(reason: string) {
  const cleaned = reason.trim();
  if (cleaned.length < 6) return { ok: false as const, error: "A public rejection reason is required." };
  if (cleaned.length > 500) return { ok: false as const, error: "Public rejection reason must be 500 characters or less." };
  return { ok: true as const, reason: cleaned };
}

export function canApproveCompany({
  companyStatus,
  isVerified = false,
  profileComplete = true,
  requiredDocumentStatuses,
}: {
  companyStatus: string;
  isVerified?: boolean | null;
  profileComplete?: boolean;
  requiredDocumentStatuses: Record<string, string | undefined>;
}) {
  return getEmployerCompanyApprovalState({
    companyStatus,
    isVerified,
    profileComplete,
    documentStatuses: requiredDocumentStatuses,
  }).canApprove;
}

function hasText(value?: string | null) {
  return Boolean(value?.trim());
}

export function isEmployerCompanyProfileComplete(company: Pick<
  EmployerCompanyAdminRow,
  "company_name" | "trade_license_number" | "industry" | "company_size" | "country" | "city" | "contact_person" | "contact_role"
>) {
  return Boolean(
    hasText(company.company_name) &&
      hasText(company.trade_license_number) &&
      hasText(company.industry) &&
      hasText(company.company_size) &&
      hasText(company.country) &&
      hasText(company.city) &&
      hasText(company.contact_person) &&
      hasText(company.contact_role),
  );
}

export function documentStatusesByType(documents: Array<Pick<EmployerDocumentAdminRow, "document_type" | "status">>) {
  const statuses: Record<string, string | undefined> = {};
  for (const type of new Set(documents.map((document) => document.document_type))) {
    const typeStatuses = documents
      .filter((document) => document.document_type === type)
      .map((document) => document.status);
    statuses[type] =
      typeStatuses.find((status) => status === "approved") ??
      typeStatuses.find((status) => status === "pending") ??
      typeStatuses.find((status) => status === "resubmission_requested") ??
      typeStatuses.find((status) => status === "rejected") ??
      typeStatuses[0];
  }
  return statuses;
}

export function getEmployerCompanyApprovalState({
  companyStatus,
  isVerified = false,
  profileComplete,
  documentStatuses,
}: {
  companyStatus: string;
  isVerified?: boolean | null;
  profileComplete: boolean;
  documentStatuses: Record<string, string | undefined>;
}) {
  if (companyStatus === "blocked") {
    return { canApprove: false, reason: "Company blocked" };
  }
  if (isVerified) {
    return { canApprove: false, reason: "Company is already approved" };
  }
  if (!profileComplete) {
    return { canApprove: false, reason: "Company profile incomplete" };
  }

  for (const type of employerRequiredDocumentTypes) {
    const status = documentStatuses[type];
    if (!status) return { canApprove: false, reason: "Trade licence not uploaded" };
    if (status === "pending" || status === "resubmission_requested") {
      return { canApprove: false, reason: "Trade licence pending review" };
    }
    if (status === "rejected") return { canApprove: false, reason: "Trade licence rejected" };
    if (status !== "approved") return { canApprove: false, reason: "Trade licence approval is required first" };
  }

  return { canApprove: true, reason: "Ready for approval" };
}

export function canBlockUser({
  actorId,
  targetId,
  actorRole,
}: {
  actorId: string;
  targetId: string;
  actorRole: string | null | undefined;
}) {
  return actorRole === "admin" && actorId !== targetId;
}
