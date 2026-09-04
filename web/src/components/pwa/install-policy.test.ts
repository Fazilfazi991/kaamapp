import { describe, expect, it } from "vitest";
import { isSafeUpdateRoute, isStableInstallRoute } from "./install-policy";

describe("PWA notice route policy", () => {
  it.each([
    "/candidate/dashboard",
    "/candidate/jobs",
    "/candidate/matches",
    "/candidate/messages",
    "/candidate/profile",
    "/employer/dashboard",
    "/employer/search",
    "/employer/job-posts",
    "/employer/messages",
    "/employer/profile",
  ])("allows a stable signed-in route: %s", (pathname) => {
    expect(isStableInstallRoute(pathname)).toBe(true);
  });

  it.each([
    "/login",
    "/register",
    "/auth/callback",
    "/candidate/onboarding",
    "/candidate/profile/edit",
    "/candidate/messages/conversation-1",
    "/employer/job-posts/new",
    "/employer/membership",
    "/employer/membership/success",
  ])("suppresses install prompts on sensitive routes: %s", (pathname) => {
    expect(isStableInstallRoute(pathname)).toBe(false);
  });

  it("only offers updates on the homepage or stable signed-in routes", () => {
    expect(isSafeUpdateRoute("/")).toBe(true);
    expect(isSafeUpdateRoute("/candidate/dashboard")).toBe(true);
    expect(isSafeUpdateRoute("/candidate/messages/conversation-1")).toBe(false);
  });
});
