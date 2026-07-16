import { describe, expect, it } from "vitest";
import {
  candidateMatchesFilters,
  filtersToSearchParams,
  parseEmployerSearchParams,
  validateFiltersAgainstSkills,
} from "./filters";
import { candidateDisplayId, mapCandidateCard, normalizePhoneForWhatsApp } from "../utils";

const categories = [{ id: "cat-1", name: "Construction", slug: "construction", icon_name: null }];
const skills = [
  { id: "skill-1", category_id: "cat-1", name: "Mason", slug: "mason" },
  { id: "skill-2", category_id: "cat-2", name: "Cleaner", slug: "cleaner" },
];

const row = {
  id: "candidate-123456",
  full_name: "Asha",
  headline: "Mason",
  nationality: "Indian",
  current_country: "UAE",
  current_city: "Dubai",
  preferred_country: "India",
  preferred_city: "Kerala",
  job_categories: ["Construction"],
  skills: ["Mason"],
  languages: ["English", "Hindi"],
  experience_years: 4,
  expected_salary_min: 1200,
  expected_salary_max: 1800,
  currency: "AED",
  availability: "Immediately Available",
  visa_status: "Employment Visa",
  profile_photo_url: null,
  bio: "Experienced mason",
  is_verified: true,
  created_at: "2026-01-01",
  updated_at: "2026-01-02",
};

describe("employer search and matching helpers", () => {
  it("sanitizes empty search parameters", () => {
    expect(parseEmployerSearchParams({}).page).toBe(1);
  });

  it("keeps UAE emirate and clears stale India state", () => {
    const parsed = parseEmployerSearchParams({ country: "UAE", emirate: "Dubai", state: "Kerala" });
    expect(parsed.emirate).toBe("Dubai");
    expect(parsed.state).toBe("");
  });

  it("keeps Indian state and clears stale UAE emirate", () => {
    const parsed = parseEmployerSearchParams({ country: "India", emirate: "Dubai", state: "Kerala" });
    expect(parsed.state).toBe("Kerala");
    expect(parsed.emirate).toBe("");
  });

  it("normalizes United Arab Emirates to UAE", () => {
    expect(parseEmployerSearchParams({ country: "United Arab Emirates" }).country).toBe("UAE");
  });

  it("rejects invalid experience values", () => {
    expect(parseEmployerSearchParams({ experience: "2 years" }).experience).toBe("");
  });

  it("rejects invalid availability values", () => {
    expect(parseEmployerSearchParams({ availability: "Tomorrow" }).availability).toBe("");
  });

  it("validates category against skill categories", () => {
    const parsed = validateFiltersAgainstSkills(
      parseEmployerSearchParams({ category: "construction" }),
      categories,
      skills,
    );
    expect(parsed.category).toBe("Construction");
  });

  it("rejects skill outside selected category", () => {
    const parsed = validateFiltersAgainstSkills(
      parseEmployerSearchParams({ category: "Construction", skill: "Cleaner" }),
      categories,
      skills,
    );
    expect(parsed.skill).toBe("");
  });

  it("accepts skill in selected category", () => {
    const parsed = validateFiltersAgainstSkills(
      parseEmployerSearchParams({ category: "Construction", skill: "Mason" }),
      categories,
      skills,
    );
    expect(parsed.skill).toBe("Mason");
  });

  it("matches no-filter search", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({}))).toBe(true);
  });

  it("excludes hidden category mismatches", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ category: "Cleaning" }))).toBe(false);
  });

  it("matches category filter", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ category: "Construction" }))).toBe(true);
  });

  it("matches skill filter", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ skill: "Mason" }))).toBe(true);
  });

  it("matches query text", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ q: "experienced" }))).toBe(true);
  });

  it("excludes query miss", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ q: "driver" }))).toBe(false);
  });

  it("matches UAE country", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ country: "UAE" }))).toBe(true);
  });

  it("matches India country through preferred location", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ country: "India" }))).toBe(true);
  });

  it("matches UAE emirate", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ country: "UAE", emirate: "Dubai" }))).toBe(true);
  });

  it("excludes stale UAE emirate miss", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ country: "UAE", emirate: "Sharjah" }))).toBe(false);
  });

  it("matches Indian state", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ country: "India", state: "Kerala" }))).toBe(true);
  });

  it("matches verified-only candidate", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ verified: "true" }))).toBe(true);
  });

  it("excludes unverified candidates for verified-only searches", () => {
    expect(candidateMatchesFilters({ ...row, is_verified: false }, parseEmployerSearchParams({ verified: "true" }))).toBe(false);
  });

  it("matches 3+ years", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ experience: "3+ years" }))).toBe(true);
  });

  it("excludes 5+ years when candidate has less", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ experience: "5+ years" }))).toBe(false);
  });

  it("matches availability exactly after normalization", () => {
    expect(candidateMatchesFilters(row, parseEmployerSearchParams({ availability: "Immediately Available" }))).toBe(true);
  });

  it("preserves filters during pagination URLs", () => {
    const query = filtersToSearchParams(parseEmployerSearchParams({ country: "UAE", emirate: "Dubai" }), { page: 2 });
    expect(query).toContain("country=UAE");
    expect(query).toContain("emirate=Dubai");
    expect(query).toContain("page=2");
  });

  it("maps privacy-safe candidate cards without contact fields", () => {
    const card = mapCandidateCard({
      row,
      shortlistedIds: new Set(),
      interestByCandidate: new Map(),
      matchedCandidateIds: new Set(),
    });
    expect(Object.keys(card)).not.toContain("phone");
    expect(Object.keys(card)).not.toContain("email");
  });

  it("maps shortlisted state", () => {
    const card = mapCandidateCard({
      row,
      shortlistedIds: new Set([row.id]),
      interestByCandidate: new Map(),
      matchedCandidateIds: new Set(),
    });
    expect(card.isShortlisted).toBe(true);
  });

  it("maps interest state", () => {
    const card = mapCandidateCard({
      row,
      shortlistedIds: new Set(),
      interestByCandidate: new Map([[row.id, "pending"]]),
      matchedCandidateIds: new Set(),
    });
    expect(card.interestStatus).toBe("pending");
  });

  it("maps match state without revealing contact values", () => {
    const card = mapCandidateCard({
      row,
      shortlistedIds: new Set(),
      interestByCandidate: new Map(),
      matchedCandidateIds: new Set([row.id]),
    });
    expect(card.isMatched).toBe(true);
    expect(JSON.stringify(card)).not.toContain("passport");
  });

  it("formats display IDs safely", () => {
    expect(candidateDisplayId("abcdef123456")).toBe("Candidate #abcdef12");
  });

  it("normalizes WhatsApp numbers without assuming country", () => {
    expect(normalizePhoneForWhatsApp("+971 50 123 4567")).toBe("971501234567");
  });
});
