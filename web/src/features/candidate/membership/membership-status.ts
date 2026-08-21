import type { CandidateMembershipRow } from "@/types/domain";

export type MembershipPresentation = {
  badge: string;
  heading: string;
  description: string;
  action: string;
  tone: "success" | "warning" | "danger";
  isActive: boolean;
  isVisible: boolean;
};

export function membershipPresentation(
  membership: CandidateMembershipRow | null,
  isVisible = false,
): MembershipPresentation {
  const active = membership?.status === "active" && membership.membership_type === "lifetime";
  if (active) {
    return {
      badge: "Lifetime Membership — Active",
      heading: "Your KAAM Membership",
      description: isVisible
        ? "Employers can currently discover your profile and send you opportunities."
        : "Your profile is temporarily hidden from employer searches. Your lifetime membership remains active.",
      action: "Manage membership",
      tone: "success",
      isActive: true,
      isVisible,
    };
  }

  return {
    badge: "Not active",
    heading: "KAAM Lifetime Membership",
    description: "Get discovered by employers and receive job opportunities with one lifetime membership.",
    action: "Activate Lifetime Membership — AED 50",
    tone: "warning",
    isActive: false,
    isVisible: false,
  };
}
