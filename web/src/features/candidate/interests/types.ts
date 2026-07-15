export type InterestStatus = "pending" | "accepted" | "rejected" | "withdrawn";

export type CandidateInterestRow = {
  id: string;
  employer_id: string;
  company_id: string;
  candidate_id: string;
  message: string | null;
  status: InterestStatus;
  created_at: string;
  updated_at: string | null;
  employer_companies?: {
    id?: string;
    company_name: string | null;
    industry: string | null;
    city: string | null;
    country?: string | null;
    logo_url?: string | null;
    description?: string | null;
    is_verified?: boolean | null;
    status?: string | null;
  } | null;
};

export type CandidateMatchRow = {
  match_id: string;
  company_name: string | null;
  role: string | null;
  location: string | null;
  matched_at: string | null;
  chat_enabled: boolean | null;
  can_reveal_contact: boolean | null;
  contact_revealed: boolean | null;
};
