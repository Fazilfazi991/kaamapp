export type UserRole = "candidate" | "employer" | "admin";

export type ProfileRow = {
  id: string;
  role: UserRole;
  full_name: string | null;
  email: string | null;
  status: string;
};

export type CandidateProfileRow = {
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
  is_verified: boolean | null;
};

export type CandidateMembershipRow = {
  status: string | null;
  plan_code: string | null;
  starts_at: string | null;
  expires_at: string | null;
};

export type EmployerCompanyRow = {
  id: string;
  company_name: string;
  industry: string | null;
  country: string | null;
  city: string | null;
  is_verified: boolean | null;
  status: string;
};

export type AccountContext = {
  userId: string;
  email: string | null;
  role: UserRole;
  profileStatus: string;
  hasCandidateProfile: boolean;
  hasEmployerProfile: boolean;
};
