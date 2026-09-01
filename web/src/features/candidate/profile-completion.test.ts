import { describe, expect, it } from "vitest";
import { routes } from "@/config/routes";
import { candidateCompletion } from "./profile-completion";
import type { CandidateProfileRow, ProfileRow } from "@/types/domain";

const profile: ProfileRow = {
  id: "user",
  role: "candidate",
  full_name: "Asha Worker",
  phone: "+971500000000",
  email: "candidate@example.com",
  status: "active",
};

const completeCandidate: CandidateProfileRow = {
  id: "user",
  headline: "Mason",
  nationality: "Indian",
  current_country: "UAE",
  current_city: "Dubai",
  preferred_country: "UAE",
  preferred_city: "Dubai",
  job_categories: ["Construction"],
  skills: ["Mason"],
  languages: ["English"],
  availability: "Immediately Available",
  is_verified: false,
};

describe("candidateCompletion", () => {
  it("calculates completed candidate profile", () => {
    const result = candidateCompletion({ profile, candidate: completeCandidate, requirePhone: true });
    expect(result.isComplete).toBe(true);
    expect(result.percentage).toBe(80);
    expect(result.isComplete).toBe(true);
    expect(result.isProfileReady).toBe(false);
  });

  it("resumes partial onboarding at the correct step", () => {
    const result = candidateCompletion({
      profile,
      candidate: { ...completeCandidate, skills: [], headline: "" },
      requirePhone: true,
    });
    expect(result.isComplete).toBe(false);
    expect(result.nextHref).toBe(routes.candidateOnboardingSkills);
  });

  it("does not mark a row-only profile complete", () => {
    const result = candidateCompletion({
      profile: { ...profile, full_name: "", phone: "" },
      candidate: { ...completeCandidate, nationality: "", availability: "" },
      requirePhone: true,
    });
    expect(result.isComplete).toBe(false);
    expect(result.percentage).toBeLessThan(100);
  });

  it("does not require passport, visa, or documents for onboarding", () => {
    const result = candidateCompletion({ profile, candidate: completeCandidate, requirePhone: true });
    expect(result.isComplete).toBe(true);
    expect(result.missingSections).toEqual([]);
    expect(result.percentage).toBeLessThan(100);
  });

  it("reaches full profile strength after a passport is uploaded", () => {
    const result = candidateCompletion({ profile, candidate: completeCandidate, requirePhone: true, hasProfileDocument: true });
    expect(result.isComplete).toBe(true);
    expect(result.isProfileReady).toBe(true);
    expect(result.percentage).toBe(100);
  });

  it("points strength CTA to documents when core profile is complete", () => {
    const result = candidateCompletion({ profile, candidate: completeCandidate, requirePhone: true });
    expect(result.strengthNextHref).toBe(routes.candidateDocuments);
  });

  it("requires mobile for the new onboarding review", () => {
    const result = candidateCompletion({ profile: { ...profile, phone: "" }, candidate: completeCandidate, requirePhone: true });
    expect(result.isComplete).toBe(false);
    expect(result.nextHref).toBe(routes.candidateOnboardingPersonal);
  });

  it("does not force an existing completed candidate back into onboarding for missing historical phone", () => {
    const result = candidateCompletion({ profile: { ...profile, phone: "" }, candidate: completeCandidate });
    expect(result.isComplete).toBe(true);
  });

  it("allows a non-UAE GCC preference without an emirate", () => {
    const result = candidateCompletion({ profile, candidate: { ...completeCandidate, preferred_country: "Qatar", preferred_city: null }, requirePhone: true });
    expect(result.isComplete).toBe(true);
  });

  it("does not keep legacy India as a valid preferred work country", () => {
    const result = candidateCompletion({ profile, candidate: { ...completeCandidate, preferred_country: "India", preferred_city: "Kerala" }, requirePhone: true });
    expect(result.isComplete).toBe(false);
    expect(result.nextHref).toBe(routes.candidateOnboardingLocation);
  });
});
