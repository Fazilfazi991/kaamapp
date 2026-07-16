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

  it("requires company information before location", () => {
    expect(nextEmployerOnboardingPath({ ...company, trade_license_number: null })).toBe("/employer/onboarding/company");
  });

  it("requires location before contact", () => {
    expect(nextEmployerOnboardingPath({ ...company, city: null })).toBe("/employer/onboarding/location");
  });

  it("requires contact before documents", () => {
    expect(nextEmployerOnboardingPath({ ...company, contact_person: null })).toBe("/employer/onboarding/contact");
  });

  it("requires trade licence document before review", () => {
    expect(nextEmployerOnboardingPath(company, [])).toBe("/employer/onboarding/documents");
  });

  it("routes complete employer to review", () => {
    expect(nextEmployerOnboardingPath(company, [document])).toBe("/employer/onboarding/review");
  });

  it("does not treat rejected documents as complete", () => {
    expect(employerCompanyCompletion(company, [{ ...document, status: "rejected" }]).documentsComplete).toBe(false);
  });

  it("separates completion from approval", () => {
    const completion = employerCompanyCompletion(company, [document]);
    expect(completion.isComplete).toBe(true);
    expect(completion.reviewStatus).toBe("pending_review");
  });
});
