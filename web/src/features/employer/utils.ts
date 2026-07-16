import type { EmployerCandidateCardModel, PublicCandidateSearchRow } from "./types";

export function interestStatusLabel(status?: string | null) {
  if (!status) return "No interest";
  return status.charAt(0).toUpperCase() + status.slice(1);
}

export function interestTone(status?: string | null): "success" | "warning" | "neutral" | "danger" {
  if (status === "accepted") return "success";
  if (status === "rejected" || status === "withdrawn") return "danger";
  if (status === "pending") return "warning";
  return "neutral";
}

export function candidateDisplayId(id: string) {
  return `Candidate #${id.slice(0, 8)}`;
}

export function mapCandidateCard({
  row,
  shortlistedIds,
  interestByCandidate,
  matchedCandidateIds,
}: {
  row: PublicCandidateSearchRow;
  shortlistedIds: Set<string>;
  interestByCandidate: Map<string, string>;
  matchedCandidateIds: Set<string>;
}): EmployerCandidateCardModel {
  const skills = row.skills?.length ? row.skills : row.job_categories ?? [];
  const currency = row.currency ?? "AED";
  const salary =
    row.expected_salary_min || row.expected_salary_max
      ? `${currency} ${row.expected_salary_min ?? ""}${row.expected_salary_min && row.expected_salary_max ? " - " : ""}${row.expected_salary_max ?? ""}`
      : "Hidden";
  return {
    id: row.id,
    displayName: row.full_name?.trim() || candidateDisplayId(row.id),
    headline: row.headline || row.job_categories?.[0] || "Candidate",
    location: [row.current_city, row.current_country].filter(Boolean).join(", ") || "Location not set",
    preferredLocation: [row.preferred_city, row.preferred_country].filter(Boolean).join(", ") || "Not set",
    availability: row.availability || "Availability not set",
    experience: `${row.experience_years ?? 0} years experience`,
    expectedSalary: salary,
    skills: skills.slice(0, 5),
    languages: row.languages ?? [],
    profilePhotoUrl: row.profile_photo_url,
    isVerified: row.is_verified === true,
    isShortlisted: shortlistedIds.has(row.id),
    interestStatus: interestByCandidate.get(row.id) ?? null,
    isMatched: matchedCandidateIds.has(row.id),
  };
}

export function normalizePhoneForWhatsApp(value: string) {
  const cleaned = value.replace(/[^\d+]/g, "");
  if (!cleaned) return "";
  return cleaned.startsWith("+") ? cleaned.slice(1) : cleaned;
}
