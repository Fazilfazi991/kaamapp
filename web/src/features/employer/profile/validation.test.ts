import { describe, expect, it } from "vitest";
import { employerCompanyCountries, employerCompanyLocationParts, validateCompanyInfo, validateEmployerContact, validateEmployerLocation, validatePhone } from "./validation";

describe("employer profile validation", () => {
  it("requires UAE emirate", () => {
    expect(validateEmployerLocation("UAE", "Kerala", "").ok).toBe(false);
  });

  it("offers the six supported GCC company countries and excludes India", () => {
    expect(employerCompanyCountries).toEqual(["UAE", "Saudi Arabia", "Qatar", "Oman", "Bahrain", "Kuwait"]);
    expect(employerCompanyCountries).not.toContain("India");
  });

  it("accepts UAE emirate", () => {
    const result = validateEmployerLocation("United Arab Emirates", "Dubai", "Al Quoz");
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value.country).toBe("UAE");
  });

  it("accepts non-UAE GCC countries without an emirate and clears stale UAE values", () => {
    for (const country of ["Saudi Arabia", "Qatar", "Oman", "Bahrain", "Kuwait"]) {
      expect(validateEmployerLocation(country, "Dubai", "")).toEqual({
        ok: true,
        value: { country, city: null, officeArea: null },
      });
    }
  });

  it("rejects India as an employer company country", () => {
    expect(validateEmployerLocation("India", "Kerala", "")).toMatchObject({ ok: false });
  });

  it("does not display a stale UAE emirate for another GCC country", () => {
    expect(employerCompanyLocationParts("Saudi Arabia", "Dubai")).toEqual(["Saudi Arabia"]);
    expect(employerCompanyLocationParts("UAE", "Dubai")).toEqual(["Dubai", "UAE"]);
  });

  it("rejects missing company name", () => {
    expect(validateCompanyInfo({ companyName: "", industry: "Facilities", companySize: "11-50", tradeLicenseNumber: "TL" }).ok).toBe(false);
  });

  it("rejects unsupported industry", () => {
    expect(validateCompanyInfo({ companyName: "Test", industry: "Magic", companySize: "11-50", tradeLicenseNumber: "TL" }).ok).toBe(false);
  });

  it("rejects invalid website", () => {
    expect(validateEmployerContact({ contactPerson: "Nadia", contactRole: "HR", website: "example" }).ok).toBe(false);
  });

  it("accepts valid website", () => {
    expect(validateEmployerContact({ contactPerson: "Nadia", contactRole: "HR", website: "https://example.com" }).ok).toBe(true);
  });

  it("rejects invalid phone", () => {
    expect(validatePhone("abc")).toBe(false);
  });

  it("accepts international phone", () => {
    expect(validatePhone("+971 50 123 4567")).toBe(true);
  });
});
