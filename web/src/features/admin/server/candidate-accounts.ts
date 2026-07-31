import { candidateCompletion } from "@/features/candidate/profile-completion";
import type {
  AdminCandidateDocumentSummary,
  AdminCandidateProfileData,
  AdminCandidateRow,
  AdminProfileRow,
} from "@/features/admin/types";

export const CANDIDATE_PAGE_SIZE = 20;

export type CandidateAccountFilter = {
  q?: string;
  status?: string;
  page?: number;
};

function textMatches(value: string | null | undefined, q: string) {
  return Boolean(value?.toLowerCase().includes(q));
}

function candidateDocumentState(documents: AdminCandidateDocumentSummary[] | null | undefined) {
  const docs = documents?.[0];
  const statuses = [docs?.passport_status, docs?.visa_status].filter(Boolean);
  if (statuses.includes("rejected")) return "rejected";
  if (statuses.includes("pending_verification")) return "pending_verification";
  return null;
}

export function candidateOperationalStatus(candidate: AdminCandidateRow) {
  if (candidate.profiles?.status === "blocked") return "blocked";
  if (!candidate.has_candidate_profile) return "profile_missing";
  if (candidate.is_verified) return "verified";

  const documentStatus = candidateDocumentState(candidate.candidate_documents);
  if (documentStatus) return documentStatus;
  if ((candidate.profile_completion ?? 0) < 100) return "incomplete";
  return "draft";
}

export function candidateOperationalStatusLabel(status: string) {
  if (status === "profile_missing") return "Profile Missing";
  return status.replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

export function composeCandidateAccount({
  profile,
  candidate,
  documents,
}: {
  profile: AdminProfileRow;
  candidate?: AdminCandidateProfileData | null;
  documents?: AdminCandidateDocumentSummary[] | null;
}): AdminCandidateRow {
  const completion = candidateCompletion({
    profile,
    candidate: candidate
      ? {
          id: candidate.id,
          headline: candidate.headline,
          nationality: candidate.nationality,
          current_country: candidate.current_country,
          current_city: candidate.current_city,
          preferred_country: candidate.preferred_country,
          preferred_city: candidate.preferred_city,
          job_categories: candidate.job_categories,
          skills: candidate.skills,
          languages: candidate.languages,
          availability: candidate.availability,
          experience_years: candidate.experience_years,
          visa_status: candidate.visa_status,
          is_visible: candidate.is_visible,
          is_verified: candidate.is_verified,
        }
      : null,
  });

  return {
    id: profile.id,
    headline: candidate?.headline ?? null,
    nationality: candidate?.nationality ?? null,
    current_country: candidate?.current_country ?? null,
    current_city: candidate?.current_city ?? null,
    preferred_country: candidate?.preferred_country ?? null,
    preferred_city: candidate?.preferred_city ?? null,
    job_categories: candidate?.job_categories ?? null,
    skills: candidate?.skills ?? null,
    languages: candidate?.languages ?? null,
    availability: candidate?.availability ?? null,
    experience_years: candidate?.experience_years ?? null,
    visa_status: candidate?.visa_status ?? null,
    is_visible: candidate?.is_visible ?? null,
    is_verified: candidate?.is_verified ?? null,
    created_at: candidate?.created_at ?? profile.created_at ?? null,
    updated_at: candidate?.updated_at ?? profile.updated_at ?? profile.created_at ?? null,
    profiles: {
      full_name: profile.full_name,
      email: profile.email,
      phone: profile.phone ?? null,
      status: profile.status,
      created_at: profile.created_at ?? null,
    },
    has_candidate_profile: Boolean(candidate),
    profile_completion: completion.percentage,
    missing_sections: completion.missingSections.map((section) => section.label),
    operational_status: "",
    candidate_documents: documents ?? null,
  };
}

export function finalizeCandidateAccount(candidate: AdminCandidateRow) {
  return {
    ...candidate,
    operational_status: candidateOperationalStatus(candidate),
  };
}

export function filterCandidateAccounts(candidates: AdminCandidateRow[], { q, status }: CandidateAccountFilter) {
  const cleanedQ = q?.trim().toLowerCase() ?? "";
  const cleanedStatus = status?.trim() ?? "";

  return candidates.filter((candidate) => {
    if (cleanedQ) {
      const matches =
        textMatches(candidate.profiles?.full_name, cleanedQ) ||
        textMatches(candidate.profiles?.email, cleanedQ) ||
        textMatches(candidate.headline, cleanedQ) ||
        textMatches(candidate.current_city, cleanedQ) ||
        textMatches(candidate.current_country, cleanedQ);
      if (!matches) return false;
    }

    if (!cleanedStatus) return true;
    if (cleanedStatus === candidate.operational_status) return true;
    return cleanedStatus === candidate.profiles?.status;
  });
}

export function paginateCandidateAccounts(candidates: AdminCandidateRow[], page = 1, pageSize = CANDIDATE_PAGE_SIZE) {
  const safePage = Math.max(1, Number.isFinite(page) ? page : 1);
  const from = (safePage - 1) * pageSize;
  return {
    page: safePage,
    rows: candidates.slice(from, from + pageSize),
    count: candidates.length,
  };
}

