import { describe, expect, it } from "vitest";
import { isCandidateOnboardingServerAction, usesVerifiedClaimsForPath } from "./middleware";

describe("Candidate onboarding middleware authentication", () => {
  it("uses verified claims only for Candidate onboarding routes", () => {
    expect(usesVerifiedClaimsForPath("/candidate/onboarding/location")).toBe(true);
    expect(usesVerifiedClaimsForPath("/candidate/onboarding/experience")).toBe(true);
    expect(usesVerifiedClaimsForPath("/candidate/onboarding-legacy")).toBe(false);
    expect(usesVerifiedClaimsForPath("/candidate/dashboard")).toBe(false);
    expect(usesVerifiedClaimsForPath("/employer/onboarding/location")).toBe(false);
  });

  it("deduplicates auth only for Candidate onboarding Server Action POSTs", () => {
    expect(isCandidateOnboardingServerAction("/candidate/onboarding/location", "POST", true)).toBe(true);
    expect(isCandidateOnboardingServerAction("/candidate/onboarding/location", "GET", true)).toBe(false);
    expect(isCandidateOnboardingServerAction("/candidate/onboarding/location", "POST", false)).toBe(false);
    expect(isCandidateOnboardingServerAction("/candidate/dashboard", "POST", true)).toBe(false);
  });
});
