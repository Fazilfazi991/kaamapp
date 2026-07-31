export const candidateVerificationStatuses = [
  "not_submitted",
  "pending_verification",
  "verified",
  "rejected",
  "reverification_required",
] as const;

export type CandidateVerificationStatus = (typeof candidateVerificationStatuses)[number];

export function candidateVerificationLabel(status?: string | null) {
  switch (status) {
    case "verified":
      return "Verified";
    case "rejected":
      return "Rejected";
    case "reverification_required":
      return "Reverification Required";
    case "not_submitted":
      return "Not Submitted";
    case "pending_verification":
    default:
      return "Awaiting Verification";
  }
}

export function candidateVerificationTone(status?: string | null): "success" | "warning" | "neutral" | "danger" {
  if (status === "verified") return "success";
  if (status === "rejected") return "danger";
  if (status === "reverification_required") return "warning";
  return "neutral";
}

export function candidateVerificationEligibility({
  accountStatus,
  profileCompletion,
  passportStatus,
}: {
  accountStatus?: string | null;
  profileCompletion: number;
  passportStatus?: string | null;
}) {
  const blockers: string[] = [];
  if (accountStatus !== "active") blockers.push("Candidate account is not active.");
  if (profileCompletion < 100) blockers.push("Required profile information is incomplete.");
  if (passportStatus !== "verified") blockers.push("Passport is not approved.");
  return { canVerify: blockers.length === 0, blockers };
}
