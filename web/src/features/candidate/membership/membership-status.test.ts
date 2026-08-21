import { describe, expect, it } from "vitest";
import { membershipPresentation } from "./membership-status";

describe("membershipPresentation", () => {
  it("keeps an unpaid Candidate hidden with an activation CTA", () => {
    const state = membershipPresentation(null);
    expect(state.isActive).toBe(false);
    expect(state.action).toBe("Activate Membership — AED 50");
    expect(state.description).toContain("lifetime membership");
  });

  it("shows an active Candidate as visible", () => {
    const state = membershipPresentation({ status: "active", plan_code: "lifetime", membership_type: "lifetime", started_at: "2026-08-17T10:00:00Z", expires_at: null }, true);
    expect(state.isActive).toBe(true);
    expect(state.badge).toBe("Lifetime Membership — Active");
    expect(state.description).toContain("Employers can currently discover");
  });

  it("does not treat a legacy expiry as a lifetime entitlement", () => {
    const state = membershipPresentation({ status: "active", plan_code: "premium", membership_type: null, started_at: "2026-06-17T10:00:00Z", expires_at: "2026-08-16T10:00:00Z" });
    expect(state.isActive).toBe(false);
    expect(state.heading).toBe("KAAM Lifetime Membership");
  });
});
