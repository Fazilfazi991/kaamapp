import { describe, expect, it } from "vitest";
import {
  authPageDecision,
  canCreateProfile,
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

  it("sends candidate accounts missing candidate profile to profile completion", () => {
    expect(
      protectedRouteDecision(
        { ...candidate, hasCandidateProfile: false },
        "candidate",
        routes.candidateDashboard,
      ),
    ).toMatchObject({
      allowed: false,
      redirectTo: routes.candidateProfile,
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

  it("unsafe external return URL is rejected", () => {
    expect(safeReturnPath("https://evil.example/candidate")).toBeNull();
    expect(safeReturnPath("//evil.example/candidate")).toBeNull();
    expect(safeReturnPath("/login?redirectTo=/employer")).toBeNull();
    expect(safeReturnPath("/candidate/dashboard")).toBe(
      routes.candidateDashboard,
    );
  });

  it("OTP normalization keeps digits only", () => {
    expect(normalizeOtp(" 12a 3-4\n56 ")).toBe("123456");
  });
});
