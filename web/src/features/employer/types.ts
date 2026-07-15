import type { SkillCategoryRow, SkillRow } from "@/types/domain";

export type EmployerCompany = {
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
  updated_at: string | null;
};

export type VerificationDocumentRow = {
  id: string;
  owner_id: string;
  company_id: string | null;
  document_type: string;
  bucket_id: string;
  file_path: string;
  status: string;
  created_at: string;
  updated_at: string | null;
};

export type PublicCandidateSearchRow = {
  id: string;
  full_name: string | null;
  headline: string | null;
  nationality: string | null;
  current_country: string | null;
  current_city: string | null;
  preferred_country: string | null;
  preferred_city: string | null;
  job_categories: string[] | null;
  skills: string[] | null;
  languages: string[] | null;
  experience_years: number | null;
  expected_salary_min: number | null;
  expected_salary_max: number | null;
  currency: string | null;
  availability: string | null;
  visa_status: string | null;
  profile_photo_url: string | null;
  bio: string | null;
  is_verified: boolean | null;
  created_at: string | null;
  updated_at: string | null;
};

export type CandidateSearchFilters = {
  q: string;
  category: string;
  skill: string;
  country: "" | "UAE" | "India";
  emirate: string;
  state: string;
  experience: string;
  availability: string;
  verified: boolean;
  page: number;
};

export type EmployerCandidateCardModel = {
  id: string;
  displayName: string;
  headline: string;
  location: string;
  preferredLocation: string;
  availability: string;
  experience: string;
  expectedSalary: string;
  skills: string[];
  languages: string[];
  profilePhotoUrl: string | null;
  isVerified: boolean;
  isShortlisted: boolean;
  interestStatus: string | null;
  isMatched: boolean;
};

export type EmployerLookupData = {
  categories: SkillCategoryRow[];
  skills: SkillRow[];
};

export type InterestRow = {
  id: string;
  employer_id: string;
  company_id: string;
  candidate_id: string;
  message: string | null;
  status: "pending" | "accepted" | "rejected" | "withdrawn";
  created_at: string;
  updated_at: string | null;
};

export type MatchContactRow = {
  match_id: string;
  candidate_id: string;
  display_name: string | null;
  role: string | null;
  location: string | null;
  matched_at: string | null;
  chat_enabled: boolean | null;
  contact_revealed: boolean | null;
  phone: string | null;
  email: string | null;
};
