import type { InterestStatus } from "./types";

export function interestStatusLabel(status?: string | null) {
  if (!status) return "Unknown";
  return status.charAt(0).toUpperCase() + status.slice(1);
}

export function interestTone(status?: string | null): "success" | "warning" | "neutral" | "danger" {
  if (status === "accepted") return "success";
  if (status === "rejected" || status === "withdrawn") return "danger";
  if (status === "pending") return "warning";
  return "neutral";
}

export function canRespondToInterest(status: InterestStatus) {
  return status === "pending";
}

export function extractInterestLine(message: string | null | undefined, label: string) {
  if (!message) return "";
  const prefix = `${label}:`;
  return (
    message
      .split(/\r?\n/)
      .find((line) => line.trim().toLowerCase().startsWith(prefix.toLowerCase()))
      ?.slice(prefix.length)
      .trim() ?? ""
  );
}

export function validateInterestTransition(current: InterestStatus, next: "accepted" | "rejected") {
  if (current !== "pending") {
    return { ok: false as const, error: `Only pending interests can be ${next}.` };
  }
  return { ok: true as const };
}
