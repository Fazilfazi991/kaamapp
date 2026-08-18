import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireRole } from "@/lib/auth/session";
import { resolveEmployerAccess } from "./access";
import {
  candidateMatchesFilters,
  employerSearchPageSize,
  parseEmployerSearchParams,
  validateFiltersAgainstSkills,
} from "@/features/employer/search/filters";
import { mapCandidateCard } from "@/features/employer/utils";
import type {
  EmployerLookupData,
  InterestRow,
  MatchContactRow,
  PublicCandidateSearchRow,
} from "@/features/employer/types";
import type { SkillCategoryRow, SkillRow } from "@/types/domain";

async function loadLookups(): Promise<EmployerLookupData> {
  const supabase = await createServerSupabaseClient();
  const [{ data: categories }, { data: skills }] = await Promise.all([
    supabase
      .from("skill_categories")
      .select("id,name,slug,icon_name")
      .eq("is_active", true)
      .order("sort_order")
      .returns<SkillCategoryRow[]>(),
    supabase
      .from("skills")
      .select("id,category_id,name,slug")
      .eq("is_active", true)
      .eq("is_approved", true)
      .order("sort_order")
      .returns<SkillRow[]>(),
  ]);
  return { categories: categories ?? [], skills: skills ?? [] };
}

async function employerState(userId: string) {
  const supabase = await createServerSupabaseClient();
  const [{ data: saved }, { data: interests }, { data: matches }] = await Promise.all([
    supabase.from("saved_candidates").select("candidate_id,created_at").eq("employer_id", userId),
    supabase
      .from("interest_requests")
      .select("id,candidate_id,status,created_at,updated_at")
      .eq("employer_id", userId)
      .returns<Array<Pick<InterestRow, "id" | "candidate_id" | "status" | "created_at" | "updated_at">>>(),
    supabase.from("matches").select("candidate_id").eq("employer_id", userId),
  ]);
  return {
    shortlistedIds: new Set((saved ?? []).map((row) => row.candidate_id as string)),
    savedRows: (saved ?? []) as Array<{ candidate_id: string; created_at: string }>,
    interestByCandidate: new Map((interests ?? []).map((row) => [row.candidate_id, row.status])),
    interests: interests ?? [],
    matchedCandidateIds: new Set((matches ?? []).map((row) => row.candidate_id as string)),
  };
}

export async function loadEmployerSearch(rawParams: Record<string, string | string[] | undefined>) {
  const access = await resolveEmployerAccess();
  const lookups = await loadLookups();
  const parsed = parseEmployerSearchParams(rawParams);
  const filters = validateFiltersAgainstSkills(parsed, lookups.categories, lookups.skills);

  if (!access.ok) {
    return {
      access,
      lookups,
      filters,
      results: [],
      total: 0,
      totalPages: 1,
      searchError: null,
    };
  }

  const supabase = await createServerSupabaseClient();

  let rows: PublicCandidateSearchRow[] = [];
  let searchError: string | null = null;
  if (filters.category && (!filters.skill || filters.skill)) {
    const { data, error } = await supabase.rpc("search_candidates_by_skills", {
      requested_category: filters.category,
      requested_skill: filters.skill || null,
    });
    if (error) searchError = "Candidate search is temporarily unavailable.";
    rows = (data ?? []) as PublicCandidateSearchRow[];
  } else {
    const { data, error } = await supabase
      .from("public_candidate_search")
      .select("*")
      .order("updated_at", { ascending: false })
      .limit(100)
      .returns<PublicCandidateSearchRow[]>();
    if (error) searchError = "Candidate search is temporarily unavailable.";
    rows = data ?? [];
  }

  const filtered = rows.filter((row) => candidateMatchesFilters(row, filters));
  const state = await employerState(access.userId);
  const totalPages = Math.max(1, Math.ceil(filtered.length / employerSearchPageSize));
  const page = Math.min(filters.page, totalPages);
  const start = (page - 1) * employerSearchPageSize;

  return {
    access,
    lookups,
    filters: { ...filters, page },
    results: filtered.slice(start, start + employerSearchPageSize).map((row) =>
      mapCandidateCard({
        row,
        shortlistedIds: state.shortlistedIds,
        interestByCandidate: state.interestByCandidate,
        matchedCandidateIds: state.matchedCandidateIds,
      }),
    ),
    total: filtered.length,
    totalPages,
    searchError,
  };
}

export async function loadEmployerCandidate(candidateId: string) {
  const access = await resolveEmployerAccess();
  if (!access.ok) return { access, candidate: null };
  const supabase = await createServerSupabaseClient();
  const [{ data: row }, state] = await Promise.all([
    supabase.from("public_candidate_search").select("*").eq("id", candidateId).maybeSingle<PublicCandidateSearchRow>(),
    employerState(access.userId),
  ]);
  if (!row) return { access, candidate: null };
  return {
    access,
    candidate: mapCandidateCard({
      row,
      shortlistedIds: state.shortlistedIds,
      interestByCandidate: state.interestByCandidate,
      matchedCandidateIds: state.matchedCandidateIds,
    }),
  };
}

export async function loadShortlist() {
  const account = await requireRole("employer");
  const supabase = await createServerSupabaseClient();
  const state = await employerState(account.userId);
  if (state.savedRows.length === 0) return { candidates: [], savedRows: [] };
  const ids = state.savedRows.map((row) => row.candidate_id);
  const { data } = await supabase
    .from("public_candidate_search")
    .select("*")
    .in("id", ids)
    .returns<PublicCandidateSearchRow[]>();
  const candidates = (data ?? []).map((row) =>
    mapCandidateCard({
      row,
      shortlistedIds: state.shortlistedIds,
      interestByCandidate: state.interestByCandidate,
      matchedCandidateIds: state.matchedCandidateIds,
    }),
  );
  return { candidates, savedRows: state.savedRows };
}

export async function loadEmployerInterests() {
  const account = await requireRole("employer");
  const supabase = await createServerSupabaseClient();
  const { data: rows } = await supabase
    .from("interest_requests")
    .select("id,employer_id,company_id,candidate_id,message,status,created_at,updated_at")
    .eq("employer_id", account.userId)
    .order("created_at", { ascending: false })
    .returns<InterestRow[]>();
  const ids = [...new Set((rows ?? []).map((row) => row.candidate_id))];
  const { data: candidates } = ids.length
    ? await supabase.from("public_candidate_search").select("*").in("id", ids).returns<PublicCandidateSearchRow[]>()
    : { data: [] as PublicCandidateSearchRow[] };
  const candidatesById = new Map((candidates ?? []).map((candidate) => [candidate.id, candidate]));
  return { rows: rows ?? [], candidatesById };
}

export async function loadEmployerMatches() {
  await requireRole("employer");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("employer_matches_with_contact");
  return { matches: (data ?? []) as MatchContactRow[], error: error ? "Could not load matches." : null };
}

export async function loadEmployerDashboard() {
  const access = await resolveEmployerAccess();
  const supabase = await createServerSupabaseClient();
  const documentsQuery = supabase
    .from("verification_documents")
    .select("id,owner_id,company_id,document_type,bucket_id,file_path,status,created_at,updated_at")
    .eq("owner_id", access.userId)
    .order("created_at", { ascending: false });

  if (!access.ok) {
    const { data: documents } = await documentsQuery;
    return { access, counts: null, documents: documents ?? [] };
  }

  const [{ count: shortlisted }, { count: interestsSent }, { count: matches }, { data: documents }] =
    await Promise.all([
      supabase.from("saved_candidates").select("*", { count: "exact", head: true }).eq("employer_id", access.userId),
      supabase.from("interest_requests").select("*", { count: "exact", head: true }).eq("employer_id", access.userId),
      supabase.from("matches").select("*", { count: "exact", head: true }).eq("employer_id", access.userId),
      documentsQuery,
    ]);

  return {
    access,
    counts: {
      shortlisted: shortlisted ?? 0,
      interestsSent: interestsSent ?? 0,
      matches: matches ?? 0,
    },
    documents: documents ?? [],
  };
}
