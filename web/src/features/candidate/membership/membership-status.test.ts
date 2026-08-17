import { describe, expect, it } from "vitest";
import { membershipPresentation } from "./membership-status";

const now = new Date("2026-08-17T10:00:00.000Z");

describe("membershipPresentation", () => {
  it("keeps an unpaid Candidate hidden with an activation CTA", () => {
    const state = membershipPresentation(null, now);
    expect(state.isActive).toBe(false);
    expect(state.action).toBe("Activate for AED 50");
    expect(state.description).toContain("appear in Employer searches");
  });

  it("shows an active Candidate as visible", () => {
    const state = membershipPresentation({ status: "active", plan_code: "premium", started_at: "2026-08-17T10:00:00Z", expires_at: "2026-10-17T10:00:00Z" }, now);
    expect(state.isActive).toBe(true);
    expect(state.badge).toBe("Active");
    expect(state.description).toContain("Visible to Employers until");
  });

  it("treats an elapsed active record as expired", () => {
    const state = membershipPresentation({ status: "active", plan_code: "premium", started_at: "2026-06-17T10:00:00Z", expires_at: "2026-08-16T10:00:00Z" }, now);
    expect(state.isActive).toBe(false);
    expect(state.heading).toBe("Membership Expired");
  });

  it("asks for a gentle renewal within seven days", () => {
    const state = membershipPresentation({ status: "active", plan_code: "premium", started_at: "2026-06-23T10:00:00Z", expires_at: "2026-08-23T10:00:00Z" }, now);
    expect(state.badge).toBe("Expires soon");
    expect(state.action).toBe("Renew for AED 50");
  });
});
