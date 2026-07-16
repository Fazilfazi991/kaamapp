import { createServerSupabaseClient } from "@/lib/supabase/server";
import type {
  AdminCandidateDocumentSummary,
  AdminCandidateProfileData,
  AdminCandidateRow,
  AdminProfileRow,
  CandidateDocumentQueueRow,
  CandidateDocumentVersionRow,
  EmployerCompanyAdminRow,
  EmployerDocumentAdminRow,
} from "@/features/admin/types";
import { normalizeCandidateDocumentStatus } from "@/features/admin/validation/review";
import {
  composeCandidateAccount,
  filterCandidateAccounts,
  finalizeCandidateAccount,
  paginateCandidateAccounts,
} from "./candidate-accounts";

const PAGE_SIZE = 20;
const CANDIDATE_PROFILE_SELECT =
  "id,headline,nationality,current_country,current_city,preferred_country,preferred_city,job_categories,skills,languages,availability,experience_years,visa_status,is_visible,is_verified,created_at,updated_at";

export type AdminListParams = {
  q?: string;
  status?: string;
  page?: number;
};

type AdminListResult<T> = {
  rows: T[];
  count: number;
  error: unknown;
  errorMessage?: string;
};

const CANDIDATE_DOCUMENT_SUMMARY_SELECT =
  "id,candidate_id,passport_file_url,visa_file_url,passport_status,visa_status,passport_uploaded_at,visa_uploaded_at,passport_expiry_date,visa_expiry_date,passport_version,visa_version,updated_at";

const CANDIDATE_DOCUMENT_VERSION_SELECT =
  "id,candidate_document_id,candidate_id,document_type,file_path,version_number,status,is_active,extracted_details,verified_at,created_at,updated_at";

function rangeFor(page = 1) {
  const safePage = Math.max(1, page);
  const from = (safePage - 1) * PAGE_SIZE;
  return { from, to: from + PAGE_SIZE - 1, page: safePage };
}

export async function countRows(table: string, filters: Array<[string, string | boolean]> = []) {
  const supabase = await createServerSupabaseClient();
  let query = supabase.from(table).select("id", { count: "exact", head: true });
  for (const [column, value] of filters) {
    query = query.eq(column, value);
  }
  const { count } = await query;
  return count ?? 0;
}

function logAdminDataError(operation: string, error: unknown) {
  if (error) {
    console.error("[admin_data]", { operation, category: "supabase_error" });
  }
}

export async function loadAdminDashboardMetrics() {
  const [
    totalCandidates,
    totalEmployers,
    pendingCandidateDocuments,
    pendingEmployerDocuments,
    approvedCandidateDocs,
    rejectedCandidateDocs,
    activeUsers,
    blockedUsers,
    recentMatches,
  ] = await Promise.all([
    countRows("profiles", [["role", "candidate"]]),
    countRows("employer_companies"),
    countRows("candidate_document_versions", [["status", "pending_verification"], ["is_active", true]]),
    countRows("verification_documents", [["status", "pending"]]),
    countRows("candidate_document_versions", [["status", "verified"]]),
    countRows("candidate_document_versions", [["status", "rejected"]]),
    countRows("profiles", [["status", "active"]]),
    countRows("profiles", [["status", "blocked"]]),
    countRows("matches"),
  ]);

  return {
    totalCandidates,
    totalEmployers,
    pendingCandidateDocuments,
    pendingEmployerDocuments,
    approvedCandidateDocs,
    rejectedCandidateDocs,
    activeUsers,
    blockedUsers,
    recentMatches,
  };
}

export async function loadCandidates({ q, status, page }: AdminListParams) {
  const supabase = await createServerSupabaseClient();
  const { data: profiles, error: profileError } = await supabase
    .from("profiles")
    .select("id,role,full_name,email,phone,status,created_at,updated_at")
    .eq("role", "candidate")
    .order("created_at", { ascending: false })
    .limit(1000);

  if (profileError) {
    logAdminDataError("load_candidate_profiles", profileError);
    return {
      rows: [],
      count: 0,
      error: profileError,
      errorMessage: "Candidate accounts could not be loaded. Please try again.",
    } satisfies AdminListResult<AdminCandidateRow>;
  }

  const candidateProfiles = (profiles ?? []) as AdminProfileRow[];
  const candidateIds = candidateProfiles.map((profile) => profile.id);
  const [{ data: candidateRows, error: candidateError }, { data: documentRows, error: documentError }] =
    candidateIds.length
      ? await Promise.all([
          supabase.from("candidate_profiles").select(CANDIDATE_PROFILE_SELECT).in("id", candidateIds),
          supabase
            .from("candidate_documents")
            .select(CANDIDATE_DOCUMENT_SUMMARY_SELECT)
            .in("candidate_id", candidateIds),
        ])
      : [
          { data: [], error: null },
          { data: [], error: null },
        ];

  if (candidateError || documentError) {
    logAdminDataError("load_candidate_related_rows", candidateError ?? documentError);
    return {
      rows: [],
      count: candidateProfiles.length,
      error: candidateError ?? documentError,
      errorMessage: "Candidate profile details could not be loaded. Please try again.",
    } satisfies AdminListResult<AdminCandidateRow>;
  }

  const candidateById = new Map(
    ((candidateRows ?? []) as AdminCandidateProfileData[]).map((candidate) => [candidate.id, candidate]),
  );
  const documentsByCandidateId = new Map<string, AdminCandidateDocumentSummary[]>();
  for (const document of (documentRows ?? []) as AdminCandidateDocumentSummary[]) {
    documentsByCandidateId.set(document.candidate_id, [document]);
  }

  const rows = candidateProfiles
    .map((profile) =>
      finalizeCandidateAccount(
        composeCandidateAccount({
          profile,
          candidate: candidateById.get(profile.id) ?? null,
          documents: documentsByCandidateId.get(profile.id) ?? null,
        }),
      ),
    );
  const filtered = filterCandidateAccounts(rows, { q, status });
  const paginated = paginateCandidateAccounts(filtered, Number(page ?? 1));
  return { ...paginated, error: null } satisfies AdminListResult<AdminCandidateRow>;
}

export async function loadCandidate(candidateId: string) {
  const supabase = await createServerSupabaseClient();
  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id,role,full_name,email,phone,status,created_at,updated_at")
    .eq("id", candidateId)
    .eq("role", "candidate")
    .maybeSingle<AdminProfileRow>();

  if (profileError) {
    logAdminDataError("load_candidate_account", profileError);
    return { candidate: null, membership: null, versions: [], notifications: [], error: profileError };
  }

  if (!profile) {
    return { candidate: null, membership: null, versions: [], notifications: [], error: null };
  }

  const [{ data: candidate }, { data: documents }, { data: membership }, { data: versions }, { data: notifications }] = await Promise.all([
    supabase
      .from("candidate_profiles")
      .select(CANDIDATE_PROFILE_SELECT)
      .eq("id", candidateId)
      .maybeSingle(),
    supabase
      .from("candidate_documents")
      .select(CANDIDATE_DOCUMENT_SUMMARY_SELECT)
      .eq("candidate_id", candidateId),
    supabase
      .from("candidate_memberships")
      .select("status,plan_code,starts_at,expires_at")
      .eq("candidate_id", candidateId)
      .order("expires_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase
      .from("candidate_document_versions")
      .select(CANDIDATE_DOCUMENT_VERSION_SELECT)
      .eq("candidate_id", candidateId)
      .order("created_at", { ascending: false }),
    supabase
      .from("candidate_document_notifications")
      .select("id,document_type,notification_type,title,body,created_at")
      .eq("candidate_id", candidateId)
      .order("created_at", { ascending: false })
      .limit(10),
  ]);

  return {
    candidate: finalizeCandidateAccount(
      composeCandidateAccount({
        profile,
        candidate: candidate as AdminCandidateProfileData | null,
        documents: (documents ?? []) as AdminCandidateDocumentSummary[],
      }),
    ),
    membership,
    versions: normalizeCandidateDocumentRows({
      versions: (versions ?? []) as CandidateDocumentVersionRow[],
      summaries: (documents ?? []) as AdminCandidateDocumentSummary[],
      profiles: [profile],
      includeHistorical: true,
    }).rows,
    notifications: notifications ?? [],
    error: null,
  };
}

export async function loadCandidateDocuments({ q, status, page }: AdminListParams) {
  const supabase = await createServerSupabaseClient();
  const { from, to } = rangeFor(page);
  const [{ data: versionRows, error: versionError }, { data: summaryRows, error: summaryError }] = await Promise.all([
    supabase
      .from("candidate_document_versions")
      .select(CANDIDATE_DOCUMENT_VERSION_SELECT)
      .order("created_at", { ascending: false })
      .limit(1000),
    supabase
      .from("candidate_documents")
      .select(CANDIDATE_DOCUMENT_SUMMARY_SELECT)
      .order("updated_at", { ascending: false })
      .limit(1000),
  ]);

  if (versionError || summaryError) {
    const error = versionError ?? summaryError;
    logAdminDataError("load_candidate_documents", error);
    return {
      rows: [],
      count: 0,
      error,
      errorMessage: "Candidate documents could not be loaded. Please try again.",
    } satisfies AdminListResult<CandidateDocumentQueueRow>;
  }

  const candidateIds = [
    ...new Set([
      ...((versionRows ?? []) as CandidateDocumentVersionRow[]).map((row) => row.candidate_id),
      ...((summaryRows ?? []) as AdminCandidateDocumentSummary[]).map((row) => row.candidate_id),
    ]),
  ];
  const { data: profileRows, error: profileError } = candidateIds.length
    ? await supabase
        .from("profiles")
        .select("id,role,full_name,email,status,created_at")
        .in("id", candidateIds)
    : { data: [], error: null };
  const { data: candidateRows, error: candidateError } = candidateIds.length
    ? await supabase
        .from("candidate_profiles")
        .select("id,headline,current_country,current_city")
        .in("id", candidateIds)
    : { data: [], error: null };

  if (profileError || candidateError) {
    const error = profileError ?? candidateError;
    logAdminDataError("load_candidate_document_profiles", error);
    return {
      rows: [],
      count: 0,
      error,
      errorMessage: "Candidate document owner details could not be loaded. Please try again.",
    } satisfies AdminListResult<CandidateDocumentQueueRow>;
  }

  const normalized = normalizeCandidateDocumentRows({
    versions: (versionRows ?? []) as CandidateDocumentVersionRow[],
    summaries: (summaryRows ?? []) as AdminCandidateDocumentSummary[],
    profiles: (profileRows ?? []) as AdminProfileRow[],
    candidateProfiles: (candidateRows ?? []) as AdminCandidateProfileData[],
    includeHistorical: status === "archived" || status === "superseded",
  }).rows.filter((row) => {
    const normalizedStatus = normalizeCandidateDocumentStatus(row.status);
    const expectedStatus = normalizeCandidateDocumentStatus(status);
    if (expectedStatus && normalizedStatus !== expectedStatus) return false;
    if (!q?.trim()) return true;
    const query = q.trim().toLowerCase();
    const owner = row.candidate_profiles?.profiles;
    return (
      row.candidate_id.toLowerCase() === query ||
      owner?.full_name?.toLowerCase().includes(query) ||
      owner?.email?.toLowerCase().includes(query) ||
      row.document_type.toLowerCase().includes(query)
    );
  });

  const rows = normalized.slice(from, to + 1);
  return { rows, count: normalized.length, error: null } satisfies AdminListResult<CandidateDocumentQueueRow>;
}

export async function loadCandidateDocument(documentId: string) {
  const supabase = await createServerSupabaseClient();
  const { data: version } = await supabase
    .from("candidate_document_versions")
    .select(CANDIDATE_DOCUMENT_VERSION_SELECT)
    .eq("id", documentId)
    .maybeSingle();
  const { data: summaryByVersion } = version?.candidate_document_id
    ? await supabase
        .from("candidate_documents")
        .select(CANDIDATE_DOCUMENT_SUMMARY_SELECT)
        .eq("id", version.candidate_document_id)
        .maybeSingle()
    : { data: null };
  const { data: summaryById } = !version
    ? await supabase
        .from("candidate_documents")
        .select(CANDIDATE_DOCUMENT_SUMMARY_SELECT)
        .eq("id", documentId)
        .maybeSingle()
    : { data: null };
  const summary = (summaryByVersion ?? summaryById) as AdminCandidateDocumentSummary | null;
  const candidateId = (version as CandidateDocumentVersionRow | null)?.candidate_id ?? summary?.candidate_id;
  if (!candidateId) return null;
  const [{ data: profile }, { data: candidate }] = await Promise.all([
    supabase
      .from("profiles")
      .select("id,role,full_name,email,status,created_at")
      .eq("id", candidateId)
      .maybeSingle<AdminProfileRow>(),
    supabase
      .from("candidate_profiles")
      .select("id,headline,current_country,current_city")
      .eq("id", candidateId)
      .maybeSingle<AdminCandidateProfileData>(),
  ]);
  const rows = normalizeCandidateDocumentRows({
    versions: version ? [version as CandidateDocumentVersionRow] : [],
    summaries: summary ? [summary] : [],
    profiles: profile ? [profile] : [],
    candidateProfiles: candidate ? [candidate] : [],
    includeHistorical: true,
  }).rows;
  return rows.find((row) => row.id === documentId) ?? rows[0] ?? null;
}

export async function loadEmployers({ q, status, page }: AdminListParams) {
  const supabase = await createServerSupabaseClient();
  const { from, to } = rangeFor(page);
  let query = supabase
    .from("employer_companies")
    .select(
      "id,owner_id,company_name,trade_license_number,industry,company_size,country,city,office_area,contact_person,contact_role,hiring_needs,website,logo_url,description,is_verified,status,created_at,updated_at,profiles(full_name,email,status),verification_documents(id,owner_id,company_id,document_type,bucket_id,file_path,status,created_at,updated_at)",
      { count: "exact" },
    )
    .order("updated_at", { ascending: false })
    .range(from, to);

  if (q) query = query.ilike("company_name", `%${q}%`);
  if (status) query = query.eq("status", status);

  const { data, count, error } = await query;
  return { rows: (data ?? []) as unknown as EmployerCompanyAdminRow[], count: count ?? 0, error };
}

export async function loadEmployer(companyId: string) {
  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("employer_companies")
    .select(
      "id,owner_id,company_name,trade_license_number,industry,company_size,country,city,office_area,contact_person,contact_role,hiring_needs,website,logo_url,description,is_verified,status,created_at,updated_at,profiles(full_name,email,status),verification_documents(id,owner_id,company_id,document_type,bucket_id,file_path,status,created_at,updated_at)",
    )
    .eq("id", companyId)
    .maybeSingle();
  return data as unknown as EmployerCompanyAdminRow | null;
}

export async function loadEmployerDocuments({ q, status, page }: AdminListParams) {
  const supabase = await createServerSupabaseClient();
  const { from, to } = rangeFor(page);
  let query = supabase
    .from("verification_documents")
    .select(
      "id,owner_id,company_id,document_type,bucket_id,file_path,status,created_at,updated_at,employer_companies(id,company_name,country,city,status,is_verified)",
      { count: "exact" },
    )
    .order("created_at", { ascending: false })
    .range(from, to);

  if (status) query = query.eq("status", status);
  if (q) query = query.eq("company_id", q);

  const { data, count, error } = await query;
  return { rows: (data ?? []) as unknown as EmployerDocumentAdminRow[], count: count ?? 0, error };
}

export async function loadEmployerDocument(documentId: string) {
  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("verification_documents")
    .select(
      "id,owner_id,company_id,document_type,bucket_id,file_path,status,created_at,updated_at,employer_companies(id,company_name,country,city,status,is_verified)",
    )
    .eq("id", documentId)
    .maybeSingle();
  return data as unknown as EmployerDocumentAdminRow | null;
}

export async function loadUsers({ q, status, page }: AdminListParams & { role?: string }) {
  const supabase = await createServerSupabaseClient();
  const { from, to } = rangeFor(page);
  let query = supabase
    .from("profiles")
    .select("id,role,full_name,email,phone,status,created_at,updated_at", { count: "exact" })
    .order("created_at", { ascending: false })
    .range(from, to);

  if (q) query = query.or(`full_name.ilike.%${q}%,email.ilike.%${q}%`);
  if (status) query = query.eq("status", status);

  const { data, count, error } = await query;
  return { rows: (data ?? []) as AdminProfileRow[], count: count ?? 0, error };
}

export async function loadUser(userId: string) {
  const supabase = await createServerSupabaseClient();
  const [{ data: profile }, { data: candidate }, { data: companies }] = await Promise.all([
    supabase
      .from("profiles")
      .select("id,role,full_name,email,phone,status,created_at,updated_at")
      .eq("id", userId)
      .maybeSingle<AdminProfileRow>(),
    supabase
      .from("candidate_profiles")
      .select("id,headline,current_country,current_city,is_verified,is_visible,updated_at")
      .eq("id", userId)
      .maybeSingle(),
    supabase
      .from("employer_companies")
      .select("id,company_name,country,city,status,is_verified,updated_at")
      .eq("owner_id", userId),
  ]);
  return { profile, candidate, companies: companies ?? [] };
}

export async function createSignedPreview(document: { bucket_id?: string | null; file_path: string }) {
  const supabase = await createServerSupabaseClient();
  const bucket = document.bucket_id || "kaam-private";
  const { data, error } = await supabase.storage.from(bucket).createSignedUrl(document.file_path, 60);
  if (error || !data?.signedUrl) return null;
  return data.signedUrl;
}

export function extractCandidateDocumentSummary(
  summaries: AdminCandidateDocumentSummary[] | null | undefined,
) {
  return summaries?.[0] ?? null;
}

export function normalizeCandidateDocumentRows({
  versions,
  summaries,
  profiles,
  candidateProfiles = [],
  includeHistorical = false,
}: {
  versions: CandidateDocumentVersionRow[];
  summaries: AdminCandidateDocumentSummary[];
  profiles: AdminProfileRow[];
  candidateProfiles?: AdminCandidateProfileData[];
  includeHistorical?: boolean;
}) {
  const profileById = new Map(profiles.map((profile) => [profile.id, profile]));
  const candidateProfileById = new Map(candidateProfiles.map((candidate) => [candidate.id, candidate]));
  const summaryByCandidateId = new Map(summaries.map((summary) => [summary.candidate_id, summary]));
  const rows = versions.map((version) =>
    withCandidateProfile(
      {
        ...version,
        status: normalizeCandidateDocumentStatus(version.status) || version.status,
        is_historical: !version.is_active,
        source: "version" as const,
        expiry_date: expiryFor(summaryByCandidateId.get(version.candidate_id), version.document_type),
      },
      profileById,
      candidateProfileById,
    ),
  );

  const versionKeys = new Set(rows.map((row) => `${row.candidate_id}:${row.document_type}`));
  for (const summary of summaries) {
    for (const documentType of ["passport", "visa"] as const) {
      const filePath = documentType === "passport" ? summary.passport_file_url : summary.visa_file_url;
      const status = documentType === "passport" ? summary.passport_status : summary.visa_status;
      const versionNumber = documentType === "passport" ? summary.passport_version : summary.visa_version;
      if (!filePath && normalizeCandidateDocumentStatus(status) === "not_uploaded") continue;
      if (versionKeys.has(`${summary.candidate_id}:${documentType}`)) continue;
      rows.push(
        withCandidateProfile(
          {
            id: summary.id,
            candidate_document_id: summary.id,
            candidate_id: summary.candidate_id,
            document_type: documentType,
            file_path: filePath ?? null,
            version_number: versionNumber ?? 1,
            status: normalizeCandidateDocumentStatus(status) || status,
            is_active: true,
            is_historical: false,
            source: "summary" as const,
            extracted_details: null,
            verified_at: null,
            created_at: uploadedAtFor(summary, documentType),
            updated_at: summary.updated_at,
            expiry_date: expiryFor(summary, documentType),
          },
          profileById,
          candidateProfileById,
        ),
      );
    }
  }

  const visibleRows = includeHistorical ? rows : latestRowsByCandidateDocument(rows);
  visibleRows.sort((a, b) => dateValue(b.created_at ?? b.updated_at) - dateValue(a.created_at ?? a.updated_at));
  return { rows: visibleRows };
}

function latestRowsByCandidateDocument(rows: CandidateDocumentQueueRow[]) {
  const byKey = new Map<string, CandidateDocumentQueueRow>();
  for (const row of rows) {
    const key = `${row.candidate_id}:${row.document_type}`;
    const existing = byKey.get(key);
    if (!existing) {
      byKey.set(key, row);
      continue;
    }
    if (row.is_active && !existing.is_active) {
      byKey.set(key, row);
      continue;
    }
    if (row.is_active === existing.is_active && row.version_number > existing.version_number) {
      byKey.set(key, row);
    }
  }
  return [...byKey.values()];
}

function withCandidateProfile(
  row: Omit<CandidateDocumentQueueRow, "candidate_profiles">,
  profileById: Map<string, AdminProfileRow>,
  candidateProfileById: Map<string, AdminCandidateProfileData>,
): CandidateDocumentQueueRow {
  const profile = profileById.get(row.candidate_id);
  const candidate = candidateProfileById.get(row.candidate_id);
  return {
    ...row,
    candidate_profiles: {
      headline: candidate?.headline ?? null,
      current_country: candidate?.current_country ?? null,
      current_city: candidate?.current_city ?? null,
      profiles: profile
        ? {
            full_name: profile.full_name,
            email: profile.email,
            status: profile.status,
          }
        : null,
    },
  };
}

function uploadedAtFor(summary: AdminCandidateDocumentSummary, type: "passport" | "visa") {
  return type === "passport" ? summary.passport_uploaded_at : summary.visa_uploaded_at;
}

function expiryFor(summary: AdminCandidateDocumentSummary | undefined, type: "passport" | "visa") {
  if (!summary) return null;
  return type === "passport" ? summary.passport_expiry_date : summary.visa_expiry_date;
}

function dateValue(value?: string | null) {
  return value ? Date.parse(value) || 0 : 0;
}
