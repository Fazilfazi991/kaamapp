import type { CandidateMembershipRow } from "@/types/domain";

export type MembershipPresentation = {
  badge: string;
  heading: string;
  description: string;
  action: string;
  tone: "success" | "warning" | "danger";
  isActive: boolean;
  expiryLabel: string | null;
};

export function membershipPresentation(
  membership: CandidateMembershipRow | null,
  now = new Date(),
): MembershipPresentation {
  const expiresAt = membership?.expires_at ? new Date(membership.expires_at) : null;
  const active = membership?.status === "active" && Boolean(expiresAt && expiresAt > now);
  const expiryLabel = expiresAt
    ? expiresAt.toLocaleDateString(undefined, { day: "numeric", month: "long", year: "numeric" })
    : null;

  if (active && expiresAt) {
    const daysRemaining = Math.ceil((expiresAt.getTime() - now.getTime()) / 86_400_000);
    if (daysRemaining <= 7) {
      return {
        badge: "Expires soon",
        heading: "Your membership expires soon",
        description: `Visible to Employers until ${expiryLabel}. Renew now to keep your profile discoverable.`,
        action: "Renew for AED 50",
        tone: "warning",
        isActive: true,
        expiryLabel,
      };
    }
    return {
      badge: "Active",
      heading: "KAAM Membership Active",
      description: `Visible to Employers until ${expiryLabel}.`,
      action: "Renew Membership",
      tone: "success",
      isActive: true,
      expiryLabel,
    };
  }

  if (membership?.status === "expired" || membership?.expires_at) {
    return {
      badge: "Expired",
      heading: "Membership Expired",
      description: "Your profile is currently hidden from Employer searches. Renew to become discoverable again.",
      action: "Renew for AED 50",
      tone: "danger",
      isActive: false,
      expiryLabel,
    };
  }

  return {
    badge: "Not active",
    heading: "Activate your KAAM profile",
    description: "Activate your profile to appear in Employer searches and receive new opportunities.",
    action: "Activate for AED 50",
    tone: "warning",
    isActive: false,
    expiryLabel: null,
  };
}
