import { describe, expect, it } from "vitest";
import {
  maxCandidateSkills,
  normalizeCountry,
  preferredWorkCountries,
  regionsForCountry,
} from "@/features/candidate/constants";
import {
  isValidInternationalMobile,
  validateCurrentResidence,
  validatePreferredWorkLocation,
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

  it("offers only GCC preferred work countries", () => {
    expect(preferredWorkCountries).toEqual(["UAE", "Saudi Arabia", "Qatar", "Oman", "Bahrain", "Kuwait"]);
    expect(preferredWorkCountries).not.toContain("India");
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

  it("validates current residence and clears incompatible combinations", () => {
    expect(validateCurrentResidence("India", "Kerala")).toMatchObject({ ok: true, value: { country: "India", region: "Kerala" } });
    expect(validateCurrentResidence("India", "Dubai")).toMatchObject({ ok: false });
    expect(validateCurrentResidence("UAE", "Kerala")).toMatchObject({ ok: false });
  });

  it("requires an emirate only for UAE preferred work", () => {
    expect(validatePreferredWorkLocation("UAE", "Dubai")).toMatchObject({ ok: true });
    expect(validatePreferredWorkLocation("UAE", "")).toMatchObject({ ok: false });
    expect(validatePreferredWorkLocation("Saudi Arabia", "Dubai")).toEqual({ ok: true, value: { country: "Saudi Arabia", region: null } });
    for (const country of ["Qatar", "Oman", "Bahrain", "Kuwait"]) {
      expect(validatePreferredWorkLocation(country, "")).toMatchObject({ ok: true, value: { country, region: null } });
    }
  });

  it("requires a normalized international mobile number", () => {
    for (const phone of ["+971500000000", "+91 70125 54342", "+94-771234567", "+8801712345678", "+923001234567", "+639171234567"]) {
      expect(isValidInternationalMobile(phone)).toBe(true);
    }
    expect(isValidInternationalMobile("0500000000")).toBe(false);
    expect(isValidInternationalMobile("+0000")).toBe(false);
  });
});
