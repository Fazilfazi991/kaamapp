import { describe, expect, it } from "vitest";
import {
  authPageDecision,
  blockedAccountMessage,
  canCreateProfile,
  isBlockedStatus,
  normalizeOtp,
  postOtpDestination,
  protectedRouteDecision,
  safeReturnPath,
  type AccountSnapshot,
} from "./routing";
import { routes } from "@/config/routes";

const unauthenticated: AccountSnapshot = {
  userId: null,
  email: null,
  role: null,
  hasCandidateProfile: false,
  hasEmployerProfile: false,
};

const candidate: AccountSnapshot = {
  userId: "user-candidate",
  email: "candidate@example.com",
  role: "candidate",
  hasCandidateProfile: true,
  hasEmployerProfile: false,
};

const employer: AccountSnapshot = {
  userId: "user-employer",
  email: "employer@example.com",
  role: "employer",
  hasCandidateProfile: false,
  hasEmployerProfile: true,
};

const admin: AccountSnapshot = {
  userId: "user-admin",
  email: "admin@example.com",
  role: "admin",
  hasCandidateProfile: false,
  hasEmployerProfile: false,
};

describe("protectedRouteDecision", () => {
  it("redirects unauthenticated candidate routes to login", () => {
    expect(
      protectedRouteDecision(
        unauthenticated,
        "candidate",
        routes.candidateDashboard,
      ),
    ).toMatchObject({ allowed: false, redirectTo: routes.login });
  });

  it("redirects unauthenticated employer routes to login", () => {
    expect(
      protectedRouteDecision(
        unauthenticated,
        "employer",
        routes.employerDashboard,
      ),
    ).toMatchObject({ allowed: false, redirectTo: routes.login });
  });

  it("allows candidate accounts to open the candidate dashboard", () => {
    expect(
      protectedRouteDecision(candidate, "candidate", routes.candidateDashboard),
    ).toMatchObject({ allowed: true });
  });

  it("prevents candidate accounts from opening employer routes", () => {
    expect(
      protectedRouteDecision(candidate, "employer", routes.employerDashboard),
    ).toMatchObject({
      allowed: false,
      redirectTo: routes.candidateDashboard,
    });
  });

  it("allows employer accounts to open the employer dashboard", () => {
    expect(
      protectedRouteDecision(employer, "employer", routes.employerDashboard),
    ).toMatchObject({ allowed: true });
  });

  it("prevents employer accounts from opening candidate routes", () => {
    expect(
      protectedRouteDecision(employer, "candidate", routes.candidateDashboard),
    ).toMatchObject({
      allowed: false,
      redirectTo: routes.employerDashboard,
    });
  });

  it("sends candidate accounts missing candidate profile to onboarding", () => {
    expect(
      protectedRouteDecision(
        { ...candidate, hasCandidateProfile: false },
        "candidate",
        routes.candidateDashboard,
      ),
    ).toMatchObject({
      allowed: false,
      redirectTo: routes.candidateOnboarding,
    });
  });

  it("sends employer accounts missing company profile to profile completion", () => {
    expect(
      protectedRouteDecision(
        { ...employer, hasEmployerProfile: false },
        "employer",
        routes.employerDashboard,
      ),
    ).toMatchObject({
      allowed: false,
      redirectTo: routes.employerProfile,
    });
  });

  it("missing profile produces recovery state", () => {
    expect(
      protectedRouteDecision(
        { ...unauthenticated, userId: "auth-user", email: "new@example.com" },
        "candidate",
        routes.candidateDashboard,
      ),
    ).toMatchObject({
      allowed: false,
      redirectTo: routes.accountRecovery,
      status: "missing_profile",
    });
  });

  it("conflicting role records produce a safe error route", () => {
    expect(
      protectedRouteDecision(
        { ...candidate, hasEmployerProfile: true },
        "candidate",
        routes.candidateDashboard,
      ),
    ).toMatchObject({
      allowed: false,
      redirectTo: routes.accountConflict,
      status: "conflicting_records",
    });
  });

  it("blocks candidate protected routes when profile status is blocked", () => {
    expect(
      protectedRouteDecision(
        { ...candidate, profileStatus: "blocked" },
        "candidate",
        routes.candidateDashboard,
      ),
    ).toMatchObject({
      allowed: false,
      redirectTo: routes.accountBlocked,
      status: "blocked",
      message: blockedAccountMessage,
    });
  });

  it("blocks employer protected routes when profile status is blocked", () => {
    expect(
      protectedRouteDecision(
        { ...employer, profileStatus: "blocked" },
        "employer",
        routes.employerDashboard,
      ),
    ).toMatchObject({
      allowed: false,
      redirectTo: routes.accountBlocked,
      status: "blocked",
    });
  });

  it("does not block an unblocked account after admin restores active status", () => {
    expect(
      protectedRouteDecision(
        { ...candidate, profileStatus: "active" },
        "candidate",
        routes.candidateDashboard,
      ),
    ).toMatchObject({ allowed: true, status: "ready" });
  });
});

describe("auth routing helpers", () => {
  it("wrong login-tab selection still redirects by backend role", () => {
    expect(postOtpDestination(candidate, "employer")).toMatchObject({
      redirectTo: routes.candidateDashboard,
      message:
        "This account is registered as a candidate. We redirected you to the correct dashboard.",
    });
  });

  it("logout-equivalent unauthenticated snapshot has no previous role", () => {
    expect(
      protectedRouteDecision(
        unauthenticated,
        "candidate",
        routes.candidateDashboard,
      ).status,
    ).toBe("unauthenticated");
  });

  it("second user login does not reuse the previous user's role", () => {
    expect(postOtpDestination(employer, "candidate").redirectTo).toBe(
      routes.employerDashboard,
    );
  });

  it("existing profile is not eligible for duplicate registration", () => {
    expect(canCreateProfile(candidate)).toBe(false);
    expect(
      canCreateProfile({
        ...unauthenticated,
        userId: "new-auth-user",
        email: "new@example.com",
      }),
    ).toBe(true);
  });

  it("authenticated user visiting login is redirected correctly", () => {
    expect(authPageDecision(candidate)).toMatchObject({
      allowed: false,
      redirectTo: routes.candidateDashboard,
    });
  });

  it("authenticated blocked user visiting login is sent to the blocked page", () => {
    expect(authPageDecision({ ...employer, profileStatus: "blocked" })).toMatchObject({
      allowed: false,
      redirectTo: routes.accountBlocked,
      status: "blocked",
    });
  });

  it("blocked admin accounts are not allowed through normal admin routing", () => {
    expect(authPageDecision({ ...admin, profileStatus: "blocked" })).toMatchObject({
      allowed: false,
      redirectTo: routes.accountBlocked,
      status: "blocked",
    });
  });

  it("post-OTP routing sends blocked accounts to the blocked page", () => {
    expect(
      postOtpDestination(
        { ...candidate, profileStatus: "blocked" },
        "candidate",
      ),
    ).toMatchObject({
      allowed: false,
      redirectTo: routes.accountBlocked,
      status: "blocked",
    });
  });

  it("blocked status detection only rejects the exact blocked state", () => {
    expect(isBlockedStatus("blocked")).toBe(true);
    expect(isBlockedStatus("active")).toBe(false);
    expect(isBlockedStatus("paused")).toBe(false);
    expect(isBlockedStatus(null)).toBe(false);
  });

  it("unsafe external return URL is rejected", () => {
    expect(safeReturnPath("https://evil.example/candidate")).toBeNull();
    expect(safeReturnPath("//evil.example/candidate")).toBeNull();
    expect(safeReturnPath("/login?redirectTo=/employer")).toBeNull();
    expect(safeReturnPath(routes.accountBlocked)).toBeNull();
    expect(safeReturnPath("/candidate/dashboard")).toBe(
      routes.candidateDashboard,
    );
  });

  it("OTP normalization keeps digits only", () => {
    expect(normalizeOtp(" 12a 3-4\n56 ")).toBe("123456");
  });
});
