import { describe, expect, it } from "vitest";
import { hasSupabaseAuthCookie, isCandidateOnboardingServerAction, usesVerifiedClaimsForPath } from "./middleware";

describe("Candidate onboarding middleware authentication", () => {
  it("uses verified claims for protected role routes only", () => {
    expect(usesVerifiedClaimsForPath("/candidate/onboarding/location")).toBe(true);
    expect(usesVerifiedClaimsForPath("/candidate/onboarding/experience")).toBe(true);
    expect(usesVerifiedClaimsForPath("/candidate/onboarding-legacy")).toBe(true);
    expect(usesVerifiedClaimsForPath("/candidate/dashboard")).toBe(true);
    expect(usesVerifiedClaimsForPath("/employer/onboarding/location")).toBe(true);
    expect(usesVerifiedClaimsForPath("/employer/dashboard")).toBe(true);
    expect(usesVerifiedClaimsForPath("/admin")).toBe(true);
    expect(usesVerifiedClaimsForPath("/admin/users")).toBe(true);
    expect(usesVerifiedClaimsForPath("/candidates/login")).toBe(false);
    expect(usesVerifiedClaimsForPath("/")).toBe(false);
  });

  it("deduplicates auth only for Candidate onboarding Server Action POSTs", () => {
    expect(isCandidateOnboardingServerAction("/candidate/onboarding/location", "POST", true)).toBe(true);
    expect(isCandidateOnboardingServerAction("/candidate/onboarding/location", "GET", true)).toBe(false);
    expect(isCandidateOnboardingServerAction("/candidate/onboarding/location", "POST", false)).toBe(false);
    expect(isCandidateOnboardingServerAction("/candidate/dashboard", "POST", true)).toBe(false);
  });
});

describe("public-route session fast path", () => {
  it("detects base and chunked Supabase auth cookies without trusting their values", () => {
    const request = (names: string[]) => ({ cookies: { getAll: () => names.map((name) => ({ name, value: "opaque" })) } });
    expect(hasSupabaseAuthCookie(request([]) as never)).toBe(false);
    expect(hasSupabaseAuthCookie(request(["theme"]) as never)).toBe(false);
    expect(hasSupabaseAuthCookie(request(["sb-project-auth-token"]) as never)).toBe(true);
    expect(hasSupabaseAuthCookie(request(["sb-project-auth-token.0"]) as never)).toBe(true);
  });
});
