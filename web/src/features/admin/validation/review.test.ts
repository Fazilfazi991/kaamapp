import { describe, expect, it } from "vitest";
import {
  canApproveCompany,
  canBlockUser,
  isAllowedCandidateDocumentApproval,
  isAllowedEmployerDocumentApproval,
  statusLabel,
  statusTone,
  validatePublicReason,
} from "./review";

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
    expect(isAllowedEmployerDocumentApproval("resubmission_requested")).toBe(true);
    expect(isAllowedEmployerDocumentApproval("approved")).toBe(false);
  });

  it("requires a useful public rejection reason", () => {
    expect(validatePublicReason("bad").ok).toBe(false);
    expect(validatePublicReason("Document is unreadable.").ok).toBe(true);
  });

  it("keeps labels and tones aligned with backend statuses", () => {
    expect(statusLabel("pending_verification")).toBe("Pending Verification");
    expect(statusTone("pending_verification")).toBe("warning");
    expect(statusTone("blocked")).toBe("danger");
    expect(statusTone("approved")).toBe("success");
  });

  it("requires actual employer document prerequisites before company approval", () => {
    expect(
      canApproveCompany({
        companyStatus: "draft",
        requiredDocumentStatuses: {
          "trade-license": "approved",
          "authorization-letter": "approved",
        },
      }),
    ).toBe(true);
    expect(
      canApproveCompany({
        companyStatus: "draft",
        requiredDocumentStatuses: {
          "trade-license": "approved",
          "authorization-letter": "pending",
        },
      }),
    ).toBe(false);
    expect(
      canApproveCompany({
        companyStatus: "blocked",
        requiredDocumentStatuses: {
          "trade-license": "approved",
          "authorization-letter": "approved",
        },
      }),
    ).toBe(false);
  });

  it("prevents admins from blocking themselves and rejects wrong role actors", () => {
    expect(canBlockUser({ actorId: "admin-1", targetId: "user-1", actorRole: "admin" })).toBe(true);
    expect(canBlockUser({ actorId: "admin-1", targetId: "admin-1", actorRole: "admin" })).toBe(false);
    expect(canBlockUser({ actorId: "candidate-1", targetId: "user-1", actorRole: "candidate" })).toBe(false);
  });
});
