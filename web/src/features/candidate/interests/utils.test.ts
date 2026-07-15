import { describe, expect, it } from "vitest";
import {
  canRespondToInterest,
  extractInterestLine,
  interestStatusLabel,
  interestTone,
  validateInterestTransition,
} from "./utils";

describe("candidate interest helpers", () => {
  it("labels actual backend statuses", () => {
    expect(interestStatusLabel("pending")).toBe("Pending");
    expect(interestStatusLabel("accepted")).toBe("Accepted");
    expect(interestStatusLabel("rejected")).toBe("Rejected");
    expect(interestStatusLabel("withdrawn")).toBe("Withdrawn");
  });

  it("maps status tones", () => {
    expect(interestTone("accepted")).toBe("success");
    expect(interestTone("pending")).toBe("warning");
    expect(interestTone("rejected")).toBe("danger");
    expect(interestTone("withdrawn")).toBe("danger");
  });

  it("allows responses only for pending interests", () => {
    expect(canRespondToInterest("pending")).toBe(true);
    expect(canRespondToInterest("accepted")).toBe(false);
    expect(canRespondToInterest("rejected")).toBe(false);
    expect(canRespondToInterest("withdrawn")).toBe(false);
  });

  it("accepts pending interest transitions", () => {
    expect(validateInterestTransition("pending", "accepted").ok).toBe(true);
  });

  it("rejects pending interest transitions", () => {
    expect(validateInterestTransition("pending", "rejected").ok).toBe(true);
  });

  it("blocks duplicate acceptance", () => {
    expect(validateInterestTransition("accepted", "accepted").ok).toBe(false);
  });

  it("blocks accepting rejected interests", () => {
    expect(validateInterestTransition("rejected", "accepted").ok).toBe(false);
  });

  it("blocks accepting withdrawn interests", () => {
    expect(validateInterestTransition("withdrawn", "accepted").ok).toBe(false);
  });

  it("extracts supported message fields", () => {
    const message = "Hello\nRole: Mason\nSalary: AED 1200\nLocation: Dubai";
    expect(extractInterestLine(message, "Role")).toBe("Mason");
    expect(extractInterestLine(message, "Salary")).toBe("AED 1200");
  });

  it("returns empty string for absent message fields", () => {
    expect(extractInterestLine("Hello", "Role")).toBe("");
  });
});
