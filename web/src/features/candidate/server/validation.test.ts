import { describe, expect, it } from "vitest";
import {
  maxCandidateSkills,
  normalizeCountry,
  regionsForCountry,
} from "@/features/candidate/constants";
import {
  validateLocationSelection,
  validateSkillIds,
} from "@/features/candidate/validation";

describe("candidate onboarding validation constants", () => {
  it("maximum three skills allowed", () => {
    expect(maxCandidateSkills).toBe(3);
  });

  it("UAE selection requires emirate dataset", () => {
    expect(regionsForCountry("UAE")).toContain("Dubai");
    expect(regionsForCountry("UAE")).not.toContain("Kerala");
  });

  it("India selection requires state dataset", () => {
    expect(regionsForCountry("India")).toContain("Kerala");
    expect(regionsForCountry("India")).not.toContain("Dubai");
  });

  it("country change normalizes legacy values", () => {
    expect(normalizeCountry("United Arab Emirates")).toBe("UAE");
    expect(normalizeCountry("India")).toBe("India");
    expect(regionsForCountry("")).toEqual([]);
  });

  it("fourth skill is rejected server-side", () => {
    expect(validateSkillIds(["a", "b", "c", "d"])).toMatchObject({
      ok: false,
    });
  });

  it("duplicate skill IDs are rejected", () => {
    expect(validateSkillIds(["a", "a"])).toMatchObject({ ok: false });
  });

  it("valid skill IDs are accepted", () => {
    expect(validateSkillIds(["a", "b", "c"])).toMatchObject({
      ok: true,
      value: ["a", "b", "c"],
    });
  });

  it("validates UAE and India locations", () => {
    expect(validateLocationSelection("UAE", "Dubai")).toMatchObject({
      ok: true,
    });
    expect(validateLocationSelection("India", "Dubai")).toMatchObject({
      ok: false,
    });
  });
});
