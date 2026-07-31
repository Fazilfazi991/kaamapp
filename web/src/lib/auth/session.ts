import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { headers } from "next/headers";
import { cache } from "react";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { webPerf } from "@/lib/perf";
import { accountDebug } from "@/lib/account-debug";
import { routes } from "@/config/routes";
import {
  authPageDecision,
  protectedRouteDecision,
  type AccountSnapshot,
  type AppAccountRole,
} from "@/lib/auth/routing";
import type {
  AccountContext,
  CandidateMembershipRow,
  CandidateProfileRow,
  EmployerCompanyRow,
  ProfileRow,
  UserRole,
} from "@/types/domain";

function currentPathFromHeaders() {
  return headers()
    .then((store) => store.get("x-current-path") ?? "")
    .catch(() => "");
}

const getAccountState = cache(async () => {
  const startedAt = performance.now();
  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return {
      user: null,
      profile: null,
      candidate: null,
      company: null,
    };
  }

  const profileStartedAt = performance.now();
  const [{ data: profile }, { data: candidate }, { data: company }] =
    await Promise.all([
      supabase
        .from("profiles")
        .select("id, role, full_name, email, status")
        .eq("id", user.id)
        .maybeSingle<ProfileRow>(),
      supabase
        .from("candidate_profiles")
        .select("id, profile_photo_url")
        .eq("id", user.id)
        .maybeSingle<Pick<CandidateProfileRow, "id" | "profile_photo_url">>(),
      supabase
        .from("employer_companies")
        .select("id")
        .eq("owner_id", user.id)
        .limit(1)
        .maybeSingle(),
    ]);

  webPerf("account profile queries", profileStartedAt);
  webPerf("authenticated account lookup", startedAt);
  accountDebug({
    userId: user.id,
    email: user.email ?? profile?.email ?? null,
    role: profile?.role ?? null,
    profileId: profile?.id ?? null,
    candidateId: candidate?.id ?? null,
    candidateName: profile?.full_name ?? null,
  });

  return { user, profile, candidate, company };
});

export const getAuthenticatedAccountSnapshot = cache(async (): Promise<AccountSnapshot> => {
  const { user, profile, candidate, company } = await getAccountState();
  if (!user) {
    return {
      userId: null,
      email: null,
      role: null,
      hasCandidateProfile: false,
      hasEmployerProfile: false,
    };
  }

  return {
    userId: user.id,
    email: user.email ?? profile?.email ?? null,
    role: profile?.role ?? null,
    hasCandidateProfile: Boolean(candidate),
    hasEmployerProfile: Boolean(company),
  };
});

export const getAuthenticatedProfile = cache(async () => {
  const { user, profile } = await getAccountState();
  return { user, profile };
});

export const requireRole = cache(async (role: AppAccountRole): Promise<AccountContext> => {
  const currentPath = await currentPathFromHeaders();
  const { user, profile, candidate, company } = await getAccountState();

  if (!user) redirect(`${routes.login}?redirectTo=${encodeURIComponent(currentPath)}`);

  const snapshot: AccountSnapshot = {
    userId: user.id,
    email: user.email ?? profile?.email ?? null,
    role: profile?.role ?? null,
    hasCandidateProfile: Boolean(candidate),
    hasEmployerProfile: Boolean(company),
  };
  const decision = protectedRouteDecision(snapshot, role, currentPath);
  if (!decision.allowed && decision.redirectTo) redirect(decision.redirectTo);

  return {
    userId: user.id,
    email: snapshot.email,
    role: profile?.role as UserRole,
    profileStatus: profile?.status ?? "draft",
    hasCandidateProfile: snapshot.hasCandidateProfile,
    hasEmployerProfile: snapshot.hasEmployerProfile,
    candidatePhotoPath: candidate?.profile_photo_url ?? null,
  };
});

export async function redirectAuthenticatedAuthPage({
  allowMissingProfile = false,
}: {
  allowMissingProfile?: boolean;
} = {}) {
  const snapshot = await getAuthenticatedAccountSnapshot();
  if (allowMissingProfile && snapshot.userId && !snapshot.role) return;
  const decision = authPageDecision(snapshot);
  if (!decision.allowed && decision.redirectTo) redirect(decision.redirectTo);
}

export async function signOutAction() {
  "use server";

  const supabase = await createServerSupabaseClient();
  await supabase.auth.signOut({ scope: "global" });
  revalidatePath("/", "layout");
  redirect(routes.login);
}

export async function loadCandidateDashboardData(userId: string) {
  const supabase = await createServerSupabaseClient();
  const [{ data: candidate }, { data: membership }] = await Promise.all([
    supabase
      .from("candidate_profiles")
      .select(
        "id, headline, nationality, current_country, current_city, preferred_country, preferred_city, job_categories, skills, languages, availability, is_verified",
      )
      .eq("id", userId)
      .maybeSingle<CandidateProfileRow>(),
    supabase
      .from("candidate_memberships")
      .select("status, plan_code, starts_at, expires_at")
      .eq("candidate_id", userId)
      .order("expires_at", { ascending: false })
      .limit(1)
      .maybeSingle<CandidateMembershipRow>(),
  ]);

  return { candidate, membership };
}

export async function loadEmployerDashboardData(userId: string) {
  const supabase = await createServerSupabaseClient();
  const { data: company } = await supabase
    .from("employer_companies")
    .select("id, company_name, industry, country, city, is_verified, status")
    .eq("owner_id", userId)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle<EmployerCompanyRow>();

  return { company };
}
