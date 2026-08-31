import { describe, expect, it } from "vitest";
import { employerCompanyCompletion, nextEmployerOnboardingPath } from "./completion";
import type { EmployerCompany, VerificationDocumentRow } from "@/features/employer/types";

const company: EmployerCompany = {
  id: "company-1",
  owner_id: "employer-1",
  company_name: "Kaam Test",
  trade_license_number: "TL-1",
  industry: "Facilities",
  company_size: "11-50",
  country: "UAE",
  city: "Dubai",
  office_area: "Al Quoz",
  contact_person: "Nadia",
  contact_role: "HR",
  hiring_needs: [],
  website: "https://example.com",
  logo_url: null,
  description: "Test",
  is_verified: false,
  status: "active",
  updated_at: null,
};

const document: VerificationDocumentRow = {
  id: "doc-1",
  owner_id: "employer-1",
  company_id: "company-1",
  document_type: "trade-license",
  bucket_id: "kaam-private",
  file_path: "employer-1/trade-license/123_trade-license_123.pdf",
  status: "pending",
  created_at: "2026-01-01T00:00:00Z",
  updated_at: null,
};

describe("employer profile completion", () => {
  it("routes employer without company to company step", () => {
    expect(nextEmployerOnboardingPath(null)).toBe("/employer/onboarding/company");
  });

  it("does not require an optional trade licence number", () => {
    expect(nextEmployerOnboardingPath({ ...company, trade_license_number: null })).toBe("/employer/dashboard");
  });

  it("requires location before contact", () => {
    expect(nextEmployerOnboardingPath({ ...company, city: null })).toBe("/employer/onboarding/location");
  });

  it("completes a non-UAE GCC location without an emirate", () => {
    expect(nextEmployerOnboardingPath({ ...company, country: "Qatar", city: null })).toBe("/employer/dashboard");
  });

  it("does not accept India as an employer company location", () => {
    expect(nextEmployerOnboardingPath({ ...company, country: "India", city: "Kerala" })).toBe("/employer/onboarding/location");
  });

  it("requires contact before completion", () => {
    expect(nextEmployerOnboardingPath({ ...company, contact_person: null })).toBe("/employer/onboarding/contact");
  });

  it("completes onboarding without verification documents", () => {
    expect(nextEmployerOnboardingPath(company, [])).toBe("/employer/dashboard");
  });

  it("keeps historical documents independent from onboarding", () => {
    expect(nextEmployerOnboardingPath(company, [document])).toBe("/employer/dashboard");
  });

  it("does not let historical document status affect completion", () => {
    expect(employerCompanyCompletion(company, [{ ...document, status: "rejected" }]).isComplete).toBe(true);
  });

  it("separates completion from approval", () => {
    const completion = employerCompanyCompletion(company, [document]);
    expect(completion.isComplete).toBe(true);
    expect(completion.reviewStatus).toBe("not_verified");
  });
});
