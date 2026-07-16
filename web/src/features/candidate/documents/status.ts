import type {
  CandidateDocumentsRow,
  CandidateDocumentStatus,
  CandidateDocumentType,
  DocumentCardModel,
} from "./types";

export const SUPPORTED_DOCUMENTS: Array<{
  type: CandidateDocumentType;
  label: string;
  description: string;
}> = [
  {
    type: "passport",
    label: "Passport",
    description: "Required identity document with OCR-assisted review.",
  },
  {
    type: "visa",
    label: "Visa / Emirates ID support",
    description: "Supporting visa fields stored in the existing candidate document record.",
  },
];

export function normalizeStatus(value?: string | null): CandidateDocumentStatus {
  const status = value?.trim() || "not_uploaded";
  if (
    status === "pending_verification" ||
    status === "verified" ||
    status === "rejected" ||
    status === "expired"
  ) {
    return status;
  }
  return "not_uploaded";
}

export function documentStatusLabel(status: string) {
  return status
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

export function documentTone(status: string): "success" | "warning" | "neutral" | "danger" {
  if (status === "verified") return "success";
  if (status === "rejected" || status === "expired") return "danger";
  if (status === "pending_verification") return "warning";
  return "neutral";
}

export function buildDocumentCards(row: CandidateDocumentsRow | null): DocumentCardModel[] {
  return SUPPORTED_DOCUMENTS.map((document) => {
    const isPassport = document.type === "passport";
    const status = normalizeStatus(isPassport ? row?.passport_status : row?.visa_status);
    const filePath = isPassport ? row?.passport_file_url : row?.visa_file_url;
    return {
      ...document,
      status,
      uploadedAt: isPassport ? row?.passport_uploaded_at ?? null : row?.visa_uploaded_at ?? null,
      expiresAt: isPassport ? row?.passport_expiry_date ?? null : row?.visa_expiry_date ?? null,
      version: isPassport ? row?.passport_version ?? 0 : row?.visa_version ?? 0,
      hasFile: Boolean(filePath && filePath.trim()),
      isVerified: Boolean(isPassport ? row?.passport_verified : row?.visa_verified),
    };
  });
}

export function fieldForDocument(type: CandidateDocumentType, field: "file" | "status" | "version") {
  const map = {
    passport: {
      file: "passport_file_url",
      status: "passport_status",
      version: "passport_version",
    },
    visa: {
      file: "visa_file_url",
      status: "visa_status",
      version: "visa_version",
    },
  } as const;
  return map[type][field];
}
