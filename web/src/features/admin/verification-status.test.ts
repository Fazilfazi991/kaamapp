import { describe, expect, it } from "vitest";
import { candidateVerificationEligibility, candidateVerificationLabel } from "./verification-status";

describe("candidate manual verification", () => {
  it("uses dedicated friendly labels instead of raw values", () => {
    expect(candidateVerificationLabel("pending_verification")).toBe("Awaiting Verification");
    expect(candidateVerificationLabel("reverification_required")).toBe("Reverification Required");
  });

  it("requires only the existing visibility prerequisites", () => {
    expect(candidateVerificationEligibility({ accountStatus: "active", profileCompletion: 100, passportStatus: "verified" }).canVerify).toBe(true);
    expect(candidateVerificationEligibility({ accountStatus: "active", profileCompletion: 100, passportStatus: "pending_verification" }).blockers).toContain("Passport is not approved.");
  });

  it("does not make visa status a manual verification requirement", () => {
    expect(candidateVerificationEligibility({ accountStatus: "active", profileCompletion: 100, passportStatus: "verified" }).canVerify).toBe(true);
  });
});
