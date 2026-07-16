import { describe, expect, it } from "vitest";
import type { AdminCandidateDocumentSummary, AdminCandidateProfileData, AdminProfileRow } from "@/features/admin/types";
import {
  composeCandidateAccount,
  filterCandidateAccounts,
  finalizeCandidateAccount,
  paginateCandidateAccounts,
} from "./candidate-accounts";

function profile(overrides: Partial<AdminProfileRow> = {}): AdminProfileRow {
  return {
    id: "candidate-1",
    role: "candidate",
    full_name: "Asha Candidate",
    email: "asha@example.com",
    phone: "+971500000000",
    status: "active",
    created_at: "2026-01-01T00:00:00Z",
    updated_at: "2026-01-02T00:00:00Z",
    ...overrides,
  };
}

function candidate(overrides: Partial<AdminCandidateProfileData> = {}): AdminCandidateProfileData {
  return {
    id: "candidate-1",
    headline: "Mason",
    nationality: "Indian",
    current_country: "UAE",
    current_city: "Dubai",
    preferred_country: "UAE",
    preferred_city: "Dubai",
    job_categories: ["Construction"],
    skills: ["Masonry"],
    languages: ["English"],
    availability: "Immediately",
    experience_years: 4,
    visa_status: "valid",
    is_visible: true,
    is_verified: false,
    created_at: "2026-01-03T00:00:00Z",
    updated_at: "2026-01-04T00:00:00Z",
    ...overrides,
  };
}

function documents(overrides: Partial<AdminCandidateDocumentSummary> = {}): AdminCandidateDocumentSummary[] {
  return [
    {
      id: "docs-1",
      candidate_id: "candidate-1",
      passport_status: "not_uploaded",
      visa_status: "not_uploaded",
      passport_uploaded_at: null,
      visa_uploaded_at: null,
      passport_expiry_date: null,
      visa_expiry_date: null,
      passport_version: null,
      visa_version: null,
      updated_at: null,
      ...overrides,
    },
  ];
}

function row({
  account = profile(),
  candidateProfile = candidate(),
  candidateDocuments = documents(),
}: {
  account?: AdminProfileRow;
  candidateProfile?: AdminCandidateProfileData | null;
  candidateDocuments?: AdminCandidateDocumentSummary[] | null;
} = {}) {
  return finalizeCandidateAccount(
    composeCandidateAccount({
      profile: account,
      candidate: candidateProfile,
      documents: candidateDocuments,
    }),
  );
}

describe("admin candidate account composition", () => {
  it("shows a candidate role with complete candidate profile", () => {
    const result = row();
    expect(result.has_candidate_profile).toBe(true);
    expect(result.profile_completion).toBe(100);
    expect(result.operational_status).toBe("draft");
  });

  it("shows a candidate role with incomplete candidate profile", () => {
    const result = row({ candidateProfile: candidate({ headline: "", skills: [] }) });
    expect(result.has_candidate_profile).toBe(true);
    expect(result.profile_completion).toBeLessThan(100);
    expect(result.operational_status).toBe("incomplete");
    expect(result.missing_sections).toContain("Skills");
  });

  it("shows a candidate role with no candidate_profiles row", () => {
    const result = row({ candidateProfile: null, candidateDocuments: null });
    expect(result.has_candidate_profile).toBe(false);
    expect(result.profile_completion).toBe(0);
    expect(result.operational_status).toBe("profile_missing");
  });

  it("keeps blocked candidates visible and labelled", () => {
    const result = row({ account: profile({ status: "blocked" }) });
    expect(result.operational_status).toBe("blocked");
  });

  it("all-status filtering includes missing profiles", () => {
    const missing = row({ candidateProfile: null, candidateDocuments: null });
    expect(filterCandidateAccounts([missing], {})).toHaveLength(1);
  });

  it("verified filter returns only verified candidates", () => {
    const verified = row({ candidateProfile: candidate({ id: "verified", is_verified: true }) });
    const incomplete = row({ candidateProfile: candidate({ id: "incomplete", headline: "" }) });
    expect(filterCandidateAccounts([verified, incomplete], { status: "verified" })).toEqual([verified]);
  });

  it("empty search does not exclude candidates", () => {
    const rows = [row(), row({ account: profile({ id: "candidate-2", full_name: "Bina Candidate" }) })];
    expect(filterCandidateAccounts(rows, { q: "" })).toHaveLength(2);
  });

  it("candidate details handle missing profile safely", () => {
    const missing = row({ candidateProfile: null, candidateDocuments: null });
    expect(missing.headline).toBeNull();
    expect(missing.current_city).toBeNull();
    expect(missing.has_candidate_profile).toBe(false);
  });

  it("pagination returns candidate accounts correctly", () => {
    const rows = Array.from({ length: 25 }, (_, index) =>
      row({ account: profile({ id: `candidate-${index + 1}` }) }),
    );
    const pageTwo = paginateCandidateAccounts(rows, 2);
    expect(pageTwo.count).toBe(25);
    expect(pageTwo.rows).toHaveLength(5);
    expect(pageTwo.rows[0].id).toBe("candidate-21");
  });
});

