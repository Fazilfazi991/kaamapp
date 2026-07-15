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
    const result = candidateCompletion({ profile, candidate: completeCandidate });
    expect(result.isComplete).toBe(true);
    expect(result.percentage).toBe(100);
  });

  it("resumes partial onboarding at the correct step", () => {
    const result = candidateCompletion({
      profile,
      candidate: { ...completeCandidate, skills: [], headline: "" },
    });
    expect(result.isComplete).toBe(false);
    expect(result.nextHref).toBe(routes.candidateOnboardingSkills);
  });

  it("does not mark a row-only profile complete", () => {
    const result = candidateCompletion({
      profile: { ...profile, full_name: "", phone: "" },
      candidate: { ...completeCandidate, nationality: "", availability: "" },
    });
    expect(result.isComplete).toBe(false);
    expect(result.percentage).toBeLessThan(100);
  });
});
