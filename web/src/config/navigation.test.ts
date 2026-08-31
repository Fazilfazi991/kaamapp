import { describe, expect, it } from "vitest";
import { candidateNavigation, employerNavigation } from "./navigation";
import { routes } from "./routes";

describe("workspace navigation", () => {
  it("keeps Candidate onboarding contextual", () => {
    expect(candidateNavigation().find((item) => item.href === routes.candidateOnboarding)?.label).toBe("Complete profile");
    expect(candidateNavigation({ profileComplete: true }).some((item) => item.href === routes.candidateOnboarding)).toBe(false);
  });

  it("disables dashboard and onboarding prefetch during Candidate onboarding", () => {
    const items = candidateNavigation({ onboarding: true });
    expect(items.find((item) => item.href === routes.candidateDashboard)?.prefetch).toBe(false);
    expect(items.find((item) => item.href === routes.candidateOnboarding)?.prefetch).toBe(false);
  });

  it("keeps Candidate and Employer navigation separate", () => {
    const candidatePaths = candidateNavigation().map((item) => item.href);
    const employerPaths = employerNavigation.map((item) => item.href);

    expect(candidatePaths).toContain(routes.candidateMembership);
    expect(candidatePaths).not.toContain(routes.employerSearch);
    expect(employerPaths).toContain(routes.employerSearch);
    expect(employerPaths).not.toContain(routes.candidateMembership);
    expect(employerPaths).not.toContain(routes.employerDocuments);
    expect(employerPaths).not.toContain(routes.employerJobPosts);
  });
});
