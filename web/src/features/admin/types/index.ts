import type { UserRole } from "@/types/domain";

export type AdminProfileStatus = "draft" | "active" | "paused" | "blocked" | string;
export type CandidateDocumentType = "passport" | "visa";
export type CandidateDocumentStatus =
  | "not_uploaded"
  | "pending_verification"
  | "pending"
  | "submitted"
  | "verified"
  | "approved"
  | "rejected"
  | "resubmission_requested"
  | "expired"
  | "archived"
  | "superseded"
  | string;
export type EmployerDocumentStatus = "pending" | "approved" | "rejected" | "resubmission_requested" | string;

export type AdminAccount = {
  userId: string;
  email: string | null;
  role: "admin";
  profileStatus: AdminProfileStatus;
};

export type AdminProfileRow = {
  id: string;
  role: UserRole;
  full_name: string | null;
  email: string | null;
  phone?: string | null;
  status: string;
  created_at?: string | null;
  updated_at?: string | null;
};

export type AdminCandidateRow = {
  id: string;
  headline: string | null;
  nationality: string | null;
  current_country: string | null;
  current_city: string | null;
  preferred_country: string | null;
  preferred_city: string | null;
  job_categories: string[] | null;
  skills: string[] | null;
  languages: string[] | null;
  availability: string | null;
  experience_years: number | null;
  visa_status: string | null;
  is_visible: boolean | null;
  is_verified: boolean | null;
  created_at: string | null;
  updated_at: string | null;
  profiles?: Pick<AdminProfileRow, "full_name" | "email" | "phone" | "status" | "created_at"> | null;
  has_candidate_profile: boolean;
  profile_completion: number;
  missing_sections: string[];
  operational_status: string;
  candidate_documents?: AdminCandidateDocumentSummary[] | null;
};

export type AdminCandidateProfileData = Omit<
  AdminCandidateRow,
  "profiles" | "has_candidate_profile" | "profile_completion" | "missing_sections" | "operational_status" | "candidate_documents"
>;

export type AdminCandidateDocumentSummary = {
  id: string;
  candidate_id: string;
  passport_file_url?: string | null;
  visa_file_url?: string | null;
  passport_status: string;
  visa_status: string;
  passport_uploaded_at: string | null;
  visa_uploaded_at: string | null;
  passport_expiry_date: string | null;
  visa_expiry_date: string | null;
  passport_version: number | null;
  visa_version: number | null;
  updated_at: string | null;
};

export type CandidateDocumentVersionRow = {
  id: string;
  candidate_document_id: string | null;
  candidate_id: string;
  document_type: CandidateDocumentType;
  file_path: string;
  version_number: number;
  status: string;
  is_active: boolean;
  extracted_details?: Record<string, unknown> | null;
  verified_at?: string | null;
  created_at: string | null;
  updated_at?: string | null;
  candidate_profiles?: {
    headline: string | null;
    current_country: string | null;
    current_city: string | null;
    profiles?: Pick<AdminProfileRow, "full_name" | "email" | "status"> | null;
  } | null;
};

export type CandidateDocumentQueueRow = {
  id: string;
  candidate_document_id: string | null;
  candidate_id: string;
  document_type: CandidateDocumentType;
  file_path: string | null;
  version_number: number;
  status: string;
  is_active: boolean;
  is_historical: boolean;
  source: "version" | "summary";
  extracted_details?: Record<string, unknown> | null;
  verified_at?: string | null;
  created_at: string | null;
  updated_at?: string | null;
  expiry_date?: string | null;
  candidate_profiles?: {
    headline: string | null;
    current_country: string | null;
    current_city: string | null;
    profiles?: Pick<AdminProfileRow, "full_name" | "email" | "status"> | null;
  } | null;
};

export type EmployerCompanyAdminRow = {
  id: string;
  owner_id: string;
  company_name: string;
  trade_license_number: string | null;
  industry: string | null;
  company_size: string | null;
  country: string | null;
  city: string | null;
  office_area: string | null;
  contact_person: string | null;
  contact_role: string | null;
  hiring_needs: string[] | null;
  website: string | null;
  logo_url: string | null;
  description: string | null;
  is_verified: boolean | null;
  status: string;
  created_at: string | null;
  updated_at: string | null;
  profiles?: Pick<AdminProfileRow, "full_name" | "email" | "status"> | null;
  verification_documents?: EmployerDocumentAdminRow[] | null;
};

export type EmployerDocumentAdminRow = {
  id: string;
  owner_id: string;
  company_id: string | null;
  document_type: string;
  bucket_id: string;
  file_path: string;
  status: string;
  created_at: string | null;
  updated_at: string | null;
  employer_companies?: Pick<EmployerCompanyAdminRow, "id" | "company_name" | "country" | "city" | "status" | "is_verified"> | null;
};
