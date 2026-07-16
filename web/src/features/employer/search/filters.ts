import { availabilityOptions, indianStates, normalizeCountry, uaeEmirates } from "@/features/candidate/constants";
import type { CandidateSearchFilters } from "@/features/employer/types";
import type { SkillCategoryRow, SkillRow } from "@/types/domain";

export const employerSearchPageSize = 12;
export const experienceOptions = ["Fresher", "3+ years", "5+ years"];

function first(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] ?? "" : value ?? "";
}

export function parseEmployerSearchParams(
  params: Record<string, string | string[] | undefined>,
): CandidateSearchFilters {
  const country = normalizeCountry(first(params.country));
  const emirate = country === "UAE" && uaeEmirates.includes(first(params.emirate)) ? first(params.emirate) : "";
  const state = country === "India" && indianStates.includes(first(params.state)) ? first(params.state) : "";
  const experience = experienceOptions.includes(first(params.experience)) ? first(params.experience) : "";
  const availability = availabilityOptions.includes(first(params.availability)) ? first(params.availability) : "";
  const page = Math.max(1, Number.parseInt(first(params.page), 10) || 1);
  return {
    q: first(params.q).trim().slice(0, 80),
    category: first(params.category).trim(),
    skill: first(params.skill).trim(),
    country: country === "UAE" || country === "India" ? country : "",
    emirate,
    state,
    experience,
    availability,
    verified: first(params.verified) === "true",
    page,
  };
}

export function validateFiltersAgainstSkills(
  filters: CandidateSearchFilters,
  categories: SkillCategoryRow[],
  skills: SkillRow[],
) {
  const category = categories.find((item) => item.name === filters.category || item.slug === filters.category);
  const categoryName = category?.name ?? "";
  const categorySkills = category ? skills.filter((skill) => skill.category_id === category.id) : skills;
  const skill = categorySkills.find((item) => item.name === filters.skill || item.slug === filters.skill);
  return {
    ...filters,
    category: categoryName,
    skill: skill?.name ?? "",
  };
}

export function filtersToSearchParams(filters: CandidateSearchFilters, overrides: Partial<CandidateSearchFilters> = {}) {
  const next = { ...filters, ...overrides };
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(next)) {
    if (key === "page" && value === 1) continue;
    if (key === "verified") {
      if (value) params.set(key, "true");
      continue;
    }
    if (value) params.set(key, String(value));
  }
  return params.toString();
}

export function candidateMatchesFilters(row: Record<string, unknown>, filters: CandidateSearchFilters) {
  const list = (value: unknown) => (Array.isArray(value) ? value.map(String) : []);
  const normalize = (value: string) => value.trim().toLowerCase();
  const overlaps = (rowValues: string[], selected: string) =>
    !selected || rowValues.map(normalize).includes(normalize(selected));
  const rowText = [
    row.full_name,
    row.headline,
    row.current_city,
    row.current_country,
    row.preferred_city,
    row.preferred_country,
    row.availability,
    row.bio,
    ...list(row.job_categories),
    ...list(row.skills),
    ...list(row.languages),
  ]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
  if (filters.q && !rowText.includes(filters.q.toLowerCase())) return false;
  if (!overlaps(list(row.job_categories), filters.category)) return false;
  if (!overlaps(list(row.skills), filters.skill)) return false;
  if (filters.country) {
    const countryText = `${row.current_country ?? ""} ${row.preferred_country ?? ""}`.toLowerCase();
    const countryNeedle = filters.country === "UAE" ? "uae" : "india";
    if (!countryText.includes(countryNeedle) && !countryText.includes(filters.country.toLowerCase())) return false;
  }
  const region = filters.country === "UAE" ? filters.emirate : filters.state;
  if (region) {
    const locationText = `${row.current_city ?? ""} ${row.preferred_city ?? ""}`.toLowerCase();
    if (!locationText.includes(region.toLowerCase())) return false;
  }
  if (filters.availability && normalize(String(row.availability ?? "")) !== normalize(filters.availability)) return false;
  if (filters.verified && row.is_verified !== true) return false;
  if (filters.experience) {
    const years = Number(row.experience_years ?? 0);
    if (filters.experience === "Fresher" && years > 0) return false;
    if (filters.experience === "3+ years" && years < 3) return false;
    if (filters.experience === "5+ years" && years < 5) return false;
  }
  return true;
}
