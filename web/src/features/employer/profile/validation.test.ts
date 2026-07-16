import { describe, expect, it } from "vitest";
import { validateCompanyInfo, validateEmployerContact, validateEmployerLocation, validatePhone } from "./validation";

describe("employer profile validation", () => {
  it("requires UAE emirate", () => {
    expect(validateEmployerLocation("UAE", "Kerala", "").ok).toBe(false);
  });

  it("requires India state", () => {
    expect(validateEmployerLocation("India", "Dubai", "").ok).toBe(false);
  });

  it("accepts UAE emirate", () => {
    const result = validateEmployerLocation("United Arab Emirates", "Dubai", "Al Quoz");
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value.country).toBe("UAE");
  });

  it("accepts Indian state", () => {
    expect(validateEmployerLocation("India", "Kerala", "").ok).toBe(true);
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
