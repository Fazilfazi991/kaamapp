import { employerRequiredDocumentTypes } from "@/features/employer/profile/completion";
import type { CandidateDocumentStatus, CandidateDocumentVersionRow, EmployerCompanyAdminRow, EmployerDocumentAdminRow, EmployerDocumentStatus } from "@/features/admin/types";

export const candidateDocumentStatuses = [
  "not_uploaded",
  "pending_verification",
  "pending",
  "submitted",
  "verified",
  "approved",
  "rejected",
  "resubmission_requested",
  "expired",
  "archived",
  "superseded",
] as const;

export const employerDocumentStatuses = [
  "pending",
  "approved",
  "rejected",
  "resubmission_requested",
] as const;

export function statusTone(status?: string | null): "success" | "warning" | "neutral" | "danger" {
  const normalized = normalizeCandidateDocumentStatus(status);
  if (!normalized) return "neutral";
  if (["verified", "approved", "active"].includes(normalized)) return "success";
  if (["pending", "pending_verification", "submitted", "draft", "paused", "resubmission_requested"].includes(normalized)) {
    return "warning";
  }
  if (["rejected", "expired", "blocked", "archived", "superseded"].includes(normalized)) return "danger";
  return "neutral";
}

export function statusLabel(status?: string | null) {
  const normalized = normalizeCandidateDocumentStatus(status);
  if (normalized === "pending_verification") return "Pending Verification";
  if (normalized === "resubmission_requested") return "Resubmission Requested";
  if (normalized === "verified") return "Approved";
  return (normalized || "unknown").replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

export function isAllowedCandidateDocumentApproval(status: CandidateDocumentStatus, isActive: boolean) {
  return isActive && normalizeCandidateDocumentStatus(status) === "pending_verification";
}

export function normalizeCandidateDocumentStatus(status?: string | null) {
  const value = status?.trim().toLowerCase().replace(/-/g, "_");
  if (!value) return "";
  if (["pending", "pending_review", "submitted"].includes(value)) return "pending_verification";
  if (value === "approved") return "verified";
  if (value === "needs_resubmission") return "resubmission_requested";
  return value;
}

export function candidateDocumentStatusOptions() {
  return [
    { value: "pending_verification", label: "Pending Verification" },
    { value: "verified", label: "Approved" },
    { value: "rejected", label: "Rejected" },
    { value: "resubmission_requested", label: "Resubmission Requested" },
    { value: "expired", label: "Expired" },
    { value: "archived", label: "Archived" },
    { value: "superseded", label: "Superseded" },
  ];
}

export function getCandidateDocumentReviewState(document?: Pick<CandidateDocumentVersionRow, "status" | "is_active"> & { source?: string } | null) {
  if (!document) {
    return { canApprove: false, canRequestResubmission: false, message: "Document was not found." };
  }
  if (document.source === "summary") {
    return {
      canApprove: false,
      canRequestResubmission: false,
      message: "This document has no reviewable version row yet. Ask the candidate to resubmit if review is required.",
    };
  }
  const status = normalizeCandidateDocumentStatus(document.status);
  const canApprove = isAllowedCandidateDocumentApproval(status, document.is_active);
  const canRequestResubmission = canApprove;
  if (status === "verified") {
    return {
      canApprove,
      canRequestResubmission,
      message: "This document has been approved. No further review action is available.",
    };
  }
  if (["rejected", "resubmission_requested"].includes(status)) {
    return {
      canApprove,
      canRequestResubmission,
      message: "This document is not pending review. Wait for a new candidate submission before taking action.",
    };
  }
  if (!document.is_active) {
    return {
      canApprove,
      canRequestResubmission,
      message: "This is a historical version. Review the active version instead.",
    };
  }
  return {
    canApprove,
    canRequestResubmission,
    message: canApprove ? "Pending review." : "This document is not eligible for review.",
  };
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
