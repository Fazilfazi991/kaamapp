import { describe, expect, it } from "vitest";
import {
  canVerifyCompany,
  canApproveEmployerDocument,
  canBlockUser,
  canRequestEmployerDocumentResubmission,
  documentStatusesByType,
  getEmployerCompanyVerificationState,
  getEmployerDocumentReviewState,
  isAllowedCandidateDocumentApproval,
  isAllowedEmployerDocumentApproval,
  isEmployerCompanyProfileComplete,
  safeActionResult,
  statusLabel,
  statusTone,
  validatePublicReason,
} from "./review";
import type { EmployerCompanyAdminRow, EmployerDocumentAdminRow } from "@/features/admin/types";

const company: EmployerCompanyAdminRow = {
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
  website: null,
  logo_url: null,
  description: null,
  is_verified: false,
  status: "draft",
  created_at: null,
  updated_at: null,
};

function employerDocument(status: string, documentType = "trade-license"): EmployerDocumentAdminRow {
  return {
    id: `${documentType}-${status}`,
    owner_id: "employer-1",
    company_id: "company-1",
    document_type: documentType,
    bucket_id: "kaam-private",
    file_path: "private/path.pdf",
    status,
    created_at: null,
    updated_at: null,
  };
}

describe("admin review validation", () => {
  it("allows only active pending candidate documents to be approved", () => {
    expect(isAllowedCandidateDocumentApproval("pending_verification", true)).toBe(true);
    expect(isAllowedCandidateDocumentApproval("verified", true)).toBe(false);
    expect(isAllowedCandidateDocumentApproval("pending_verification", false)).toBe(false);
  });

  it("prevents approving candidate documents twice", () => {
    expect(isAllowedCandidateDocumentApproval("verified", true)).toBe(false);
  });

  it("allows employer document approval from pending or resubmission states only", () => {
    expect(isAllowedEmployerDocumentApproval("pending")).toBe(true);
    expect(isAllowedEmployerDocumentApproval("resubmission_requested")).toBe(false);
    expect(isAllowedEmployerDocumentApproval("approved")).toBe(false);
  });

  it("pending trade licence shows approve and request resubmission", () => {
    expect(canApproveEmployerDocument(employerDocument("pending"))).toBe(true);
    expect(canRequestEmployerDocumentResubmission(employerDocument("pending"))).toBe(true);
  });

  it("approved trade licence hides all review controls", () => {
    const state = getEmployerDocumentReviewState(employerDocument("approved"));
    expect(state.canApprove).toBe(false);
    expect(state.canRequestResubmission).toBe(false);
    expect(state.message).toContain("approved");
  });

  it("rejected and superseded documents cannot be approved through stale UI", () => {
    expect(canApproveEmployerDocument(employerDocument("rejected"))).toBe(false);
    expect(canApproveEmployerDocument(employerDocument("superseded"))).toBe(false);
  });

  it("requires a useful public rejection reason", () => {
    expect(validatePublicReason("bad").ok).toBe(false);
    expect(validatePublicReason("Document is unreadable.").ok).toBe(true);
  });

  it("keeps labels and tones aligned with backend statuses", () => {
    expect(statusLabel("pending_verification")).toBe("Pending Review");
    expect(statusTone("pending_verification")).toBe("warning");
    expect(statusTone("blocked")).toBe("danger");
    expect(statusTone("approved")).toBe("success");
  });

  it("does not require employer documents before optional business verification", () => {
    expect(
      canVerifyCompany({
        companyStatus: "draft",
        requiredDocumentStatuses: {},
      }),
    ).toBe(true);
    expect(
      canVerifyCompany({
        companyStatus: "draft",
        requiredDocumentStatuses: { "authorization-letter": "pending" },
      }),
    ).toBe(true);
    expect(
      canVerifyCompany({
        companyStatus: "blocked",
        requiredDocumentStatuses: {},
      }),
    ).toBe(false);
  });

  it("company can be verified with no verification documents", () => {
    const state = getEmployerCompanyVerificationState({
      companyStatus: "draft",
      profileComplete: true,
      documentStatuses: {},
    });
    expect(state.canApprove).toBe(true);
  });

  it("historical pending documents do not block optional verification", () => {
    const state = getEmployerCompanyVerificationState({
      companyStatus: "draft",
      profileComplete: true,
      documentStatuses: {
        "authorization-letter": "pending",
      },
    });
    expect(state.canApprove).toBe(true);
  });

  it("missing, pending, or rejected trade licences do not block optional verification", () => {
    expect(getEmployerCompanyVerificationState({ companyStatus: "draft", profileComplete: true, documentStatuses: {} }).canApprove).toBe(true);
    expect(getEmployerCompanyVerificationState({ companyStatus: "draft", profileComplete: true, documentStatuses: { "trade-license": "pending" } }).canApprove).toBe(true);
    expect(getEmployerCompanyVerificationState({ companyStatus: "draft", profileComplete: true, documentStatuses: { "trade-license": "rejected" } }).canApprove).toBe(true);
  });

  it("company profile completeness is checked before optional verification", () => {
    expect(isEmployerCompanyProfileComplete(company)).toBe(true);
    expect(isEmployerCompanyProfileComplete({ ...company, contact_person: null })).toBe(false);
  });

  it("already verified company hides the verification button", () => {
    const state = getEmployerCompanyVerificationState({
      companyStatus: "active",
      isVerified: true,
      profileComplete: true,
      documentStatuses: {},
    });
    expect(state.canApprove).toBe(false);
    expect(state.reason).toBe("Business is already verified");
  });

  it("document status mapping keeps authorization letter optional", () => {
    expect(documentStatusesByType([
      employerDocument("approved"),
      employerDocument("pending", "authorization-letter"),
    ])).toMatchObject({
      "trade-license": "approved",
      "authorization-letter": "pending",
    });
  });

  it("safe action results do not expose raw backend details", () => {
    const result = safeActionResult("Could not approve employer document. Please try again.");
    expect(result.message).not.toMatch(/select|update|permission denied|Supabase/i);
  });

  it("prevents admins from blocking themselves and rejects wrong role actors", () => {
    expect(canBlockUser({ actorId: "admin-1", targetId: "user-1", actorRole: "admin" })).toBe(true);
    expect(canBlockUser({ actorId: "admin-1", targetId: "admin-1", actorRole: "admin" })).toBe(false);
    expect(canBlockUser({ actorId: "candidate-1", targetId: "user-1", actorRole: "candidate" })).toBe(false);
  });
});
