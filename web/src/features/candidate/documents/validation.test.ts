import { describe, expect, it } from "vitest";
import {
  buildPrivateDocumentPath,
  MAX_DOCUMENT_BYTES,
  validateDocumentFile,
  validatePassportReview,
} from "./validation";
import { buildDocumentCards, normalizeStatus } from "./status";
import { mapPassportOcrResponse } from "./ocr";

describe("candidate document validation", () => {
  it("accepts passport image uploads", () => {
    expect(validateDocumentFile({ type: "passport", mimeType: "image/jpeg", size: 1000 })).toEqual({
      ok: true,
      extension: "jpg",
    });
  });

  it("rejects passport PDFs because OCR expects images", () => {
    expect(validateDocumentFile({ type: "passport", mimeType: "application/pdf", size: 1000 })).toEqual({
      ok: false,
      error: "Passport OCR supports JPG, PNG, or WebP images.",
    });
  });

  it("accepts visa PDF uploads", () => {
    expect(validateDocumentFile({ type: "visa", mimeType: "application/pdf", size: 1000 })).toEqual({
      ok: true,
      extension: "pdf",
    });
  });

  it("rejects oversized files", () => {
    const result = validateDocumentFile({
      type: "visa",
      mimeType: "image/png",
      size: MAX_DOCUMENT_BYTES + 1,
    });
    expect(result.ok).toBe(false);
  });

  it("builds private storage paths under the candidate document folder", () => {
    expect(
      buildPrivateDocumentPath({
        userId: "user-1",
        documentType: "passport",
        extension: "jpg",
        now: 123,
      }),
    ).toBe("user-1/candidate-documents/passport/123_passport_123.jpg");
  });

  it("normalizes unknown statuses to not uploaded", () => {
    expect(normalizeStatus("strange")).toBe("not_uploaded");
  });

  it("keeps pending status visible on dashboard cards", () => {
    const [passport] = buildDocumentCards({
      id: "doc",
      candidate_id: "user-1",
      passport_file_url: "user-1/candidate-documents/passport/a.jpg",
      visa_file_url: null,
      passport_number: null,
      passport_issue_date: null,
      passport_expiry_date: "2030-01-01",
      country_of_issue: null,
      full_name: null,
      nationality: null,
      gender: null,
      dob: null,
      place_of_birth: null,
      visa_number: null,
      visa_type: null,
      occupation: null,
      sponsor: null,
      uid_number: null,
      emirates_id: null,
      visa_issue_date: null,
      visa_expiry_date: null,
      passport_verified: false,
      visa_verified: false,
      ocr_completed: false,
      passport_status: "pending_verification",
      visa_status: "not_uploaded",
      passport_uploaded_at: "2026-01-01T00:00:00Z",
      visa_uploaded_at: null,
      passport_verified_at: null,
      visa_verified_at: null,
      passport_version: 2,
      visa_version: 0,
      passport_is_active: true,
      visa_is_active: false,
      passport_archived: true,
      visa_archived: false,
      updated_at: "2026-01-01T00:00:00Z",
    });
    expect(passport.status).toBe("pending_verification");
    expect(passport.hasFile).toBe(true);
    expect(passport.version).toBe(2);
  });

  it("maps common OCR response keys", () => {
    const mapped = mapPassportOcrResponse({
      data: {
        fullName: "Asha Kumar",
        passportNumber: "P123",
        nationality: "IND",
        dateOfBirth: "1990-02-03",
        issueDate: "2020-01-01",
        expiryDate: "2030-01-01",
      },
    });
    expect(mapped.full_name).toBe("Asha Kumar");
    expect(mapped.passport_number).toBe("P123");
    expect(mapped.dob).toBe("1990-02-03");
    expect(mapped.hasAnyData).toBe(true);
  });

  it("maps fallback document number keys", () => {
    const mapped = mapPassportOcrResponse({ document_number: "Z9", holder_name: "Sam Lee" });
    expect(mapped.passport_number).toBe("Z9");
    expect(mapped.full_name).toBe("Sam Lee");
  });

  it("parses non-ISO OCR dates", () => {
    const mapped = mapPassportOcrResponse({ date_of_birth: "05/04/1991" });
    expect(mapped.dob).toBe("1991-04-05");
  });

  it("validates required passport review fields", () => {
    const result = validatePassportReview({
      full_name: "",
      passport_number: "P123",
      nationality: "IND",
      dob: "1990-01-01",
      gender: "",
      passport_issue_date: "",
      passport_expiry_date: "2030-01-01",
      place_of_birth: "",
      country_of_issue: "",
    });
    expect(result.ok).toBe(false);
  });

  it("rejects issue dates after expiry dates", () => {
    const result = validatePassportReview({
      full_name: "Asha Kumar",
      passport_number: "P123",
      nationality: "IND",
      dob: "1990-01-01",
      gender: "",
      passport_issue_date: "2031-01-01",
      passport_expiry_date: "2030-01-01",
      place_of_birth: "",
      country_of_issue: "",
    });
    expect(result.ok).toBe(false);
  });

  it("accepts complete passport review fields", () => {
    const result = validatePassportReview({
      full_name: "Asha Kumar",
      passport_number: "P123",
      nationality: "IND",
      dob: "1990-01-01",
      gender: "F",
      passport_issue_date: "2020-01-01",
      passport_expiry_date: "2030-01-01",
      place_of_birth: "Kochi",
      country_of_issue: "IND",
    });
    expect(result.ok).toBe(true);
  });
});
