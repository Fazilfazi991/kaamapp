export type CandidateDocumentType = "passport" | "visa";

export type CandidateDocumentStatus =
  | "not_uploaded"
  | "pending_verification"
  | "verified"
  | "rejected"
  | "expired";

export type CandidateDocumentsRow = {
  id: string;
  candidate_id: string;
  passport_file_url: string | null;
  visa_file_url: string | null;
  passport_number: string | null;
  passport_issue_date: string | null;
  passport_expiry_date: string | null;
  country_of_issue: string | null;
  full_name: string | null;
  nationality: string | null;
  gender: string | null;
  dob: string | null;
  place_of_birth: string | null;
  visa_number: string | null;
  visa_type: string | null;
  occupation: string | null;
  sponsor: string | null;
  uid_number: string | null;
  emirates_id: string | null;
  visa_issue_date: string | null;
  visa_expiry_date: string | null;
  passport_verified: boolean | null;
  visa_verified: boolean | null;
  ocr_completed: boolean | null;
  passport_status: CandidateDocumentStatus | string | null;
  visa_status: CandidateDocumentStatus | string | null;
  passport_uploaded_at: string | null;
  visa_uploaded_at: string | null;
  passport_verified_at: string | null;
  visa_verified_at: string | null;
  passport_version: number | null;
  visa_version: number | null;
  passport_is_active: boolean | null;
  visa_is_active: boolean | null;
  passport_archived: boolean | null;
  visa_archived: boolean | null;
  updated_at: string | null;
};

export type DocumentVersionRow = {
  id: string;
  candidate_document_id: string | null;
  candidate_id: string;
  document_type: CandidateDocumentType;
  file_path: string;
  version_number: number;
  status: string;
  is_active: boolean;
  extracted_details?: Record<string, unknown> | null;
  created_at: string;
};

export type DocumentCardModel = {
  type: CandidateDocumentType;
  label: string;
  description: string;
  status: string;
  uploadedAt: string | null;
  expiresAt: string | null;
  version: number;
  hasFile: boolean;
  isVerified: boolean;
};

export type PassportReviewValues = {
  full_name: string;
  passport_number: string;
  nationality: string;
  dob: string;
  gender: string;
  passport_issue_date: string;
  passport_expiry_date: string;
  place_of_birth: string;
  country_of_issue: string;
};
