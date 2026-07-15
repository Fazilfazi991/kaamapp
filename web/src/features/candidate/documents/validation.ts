import type { CandidateDocumentType, PassportReviewValues } from "./types";

export const MAX_DOCUMENT_BYTES = 10 * 1024 * 1024;
export const IMAGE_DOCUMENT_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
export const PDF_DOCUMENT_TYPE = "application/pdf";

const EXTENSION_BY_TYPE: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "application/pdf": "pdf",
};

export type FileValidationResult =
  | { ok: true; extension: string }
  | { ok: false; error: string };

export function validateDocumentFile({
  type,
  mimeType,
  size,
}: {
  type: CandidateDocumentType;
  mimeType: string;
  size: number;
}): FileValidationResult {
  if (!size) return { ok: false, error: "Choose a document file first." };
  if (size > MAX_DOCUMENT_BYTES) {
    return { ok: false, error: "This file is larger than 10 MB. Choose a smaller file." };
  }

  const supported: readonly string[] =
    type === "passport" ? IMAGE_DOCUMENT_TYPES : [...IMAGE_DOCUMENT_TYPES, PDF_DOCUMENT_TYPE];
  if (!supported.includes(mimeType)) {
    return {
      ok: false,
      error:
        type === "passport"
          ? "Passport OCR supports JPG, PNG, or WebP images."
          : "Use a JPG, PNG, WebP, or PDF file.",
    };
  }

  return { ok: true, extension: EXTENSION_BY_TYPE[mimeType] ?? "bin" };
}

export function buildPrivateDocumentPath({
  userId,
  documentType,
  extension,
  now = Date.now(),
}: {
  userId: string;
  documentType: CandidateDocumentType;
  extension: string;
  now?: number;
}) {
  const safeType = documentType.replace(/[^a-z0-9_-]/gi, "").toLowerCase();
  const safeExtension = extension.replace(/[^a-z0-9]/gi, "").toLowerCase() || "jpg";
  return `${userId}/candidate-documents/${safeType}/${now}_${safeType}_${now}.${safeExtension}`;
}

export function cleanText(value: FormDataEntryValue | string | null | undefined) {
  return String(value ?? "").replace(/\s+/g, " ").trim();
}

export function validIsoDate(value: string) {
  if (!value) return false;
  const parsed = Date.parse(`${value}T00:00:00.000Z`);
  return Number.isFinite(parsed) && /^\d{4}-\d{2}-\d{2}$/.test(value);
}

export function validatePassportReview(values: PassportReviewValues):
  | { ok: true; value: PassportReviewValues }
  | { ok: false; error: string } {
  if (!values.full_name) return { ok: false, error: "Full name is required." };
  if (!values.passport_number) return { ok: false, error: "Passport number is required." };
  if (!values.nationality) return { ok: false, error: "Nationality is required." };
  if (!validIsoDate(values.dob)) return { ok: false, error: "Enter a valid date of birth." };
  if (!validIsoDate(values.passport_expiry_date)) {
    return { ok: false, error: "Enter a valid passport expiry date." };
  }
  if (values.passport_issue_date && !validIsoDate(values.passport_issue_date)) {
    return { ok: false, error: "Enter a valid passport issue date." };
  }
  if (
    values.passport_issue_date &&
    Date.parse(values.passport_issue_date) > Date.parse(values.passport_expiry_date)
  ) {
    return { ok: false, error: "Passport issue date cannot be after the expiry date." };
  }
  return { ok: true, value: values };
}

export function omitEmpty(values: Record<string, string | boolean | null>) {
  return Object.fromEntries(
    Object.entries(values).map(([key, value]) => [key, value === "" ? null : value]),
  );
}
