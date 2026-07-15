import type { CandidateDocumentStatus, EmployerDocumentStatus } from "@/features/admin/types";

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

export function isAllowedEmployerDocumentApproval(status: EmployerDocumentStatus) {
  return status === "pending" || status === "resubmission_requested";
}

export function validatePublicReason(reason: string) {
  const cleaned = reason.trim();
  if (cleaned.length < 6) return { ok: false as const, error: "A public rejection reason is required." };
  if (cleaned.length > 500) return { ok: false as const, error: "Public rejection reason must be 500 characters or less." };
  return { ok: true as const, reason: cleaned };
}

export function canApproveCompany({
  companyStatus,
  requiredDocumentStatuses,
}: {
  companyStatus: string;
  requiredDocumentStatuses: Record<string, string | undefined>;
}) {
  if (companyStatus === "blocked") return false;
  return ["trade-license", "authorization-letter"].every(
    (type) => requiredDocumentStatuses[type] === "approved",
  );
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
