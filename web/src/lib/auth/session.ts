import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { headers } from "next/headers";
import { cache } from "react";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { routes } from "@/config/routes";
import {
  authPageDecision,
  accountSetupDecision,
  dashboardForRole,
  profileRecoveryDecision,
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
import { supabaseConfigError } from "@/lib/supabase/env";

export type PublicAccountNavigation = {
  authenticated: boolean;
  role: UserRole | null;
  displayName: string | null;
  dashboardHref: string | null;
};

function currentPathFromHeaders() {
  return headers()
    .then((store) => store.get("x-current-path") ?? "")
    .catch(() => "");
}

export async function getAuthenticatedAccountSnapshot(): Promise<AccountSnapshot> {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return {
      userId: null,
      email: null,
      role: null,
      hasCandidateProfile: false,
      hasEmployerProfile: false,
    };
  }

  const [{ data: profile }, { data: candidate }, { data: company }] =
    await Promise.all([
      supabase
        .from("profiles")
        .select("id, role, full_name, email, status")
        .eq("id", user.id)
        .maybeSingle<ProfileRow>(),
      supabase.from("candidate_profiles").select("id").eq("id", user.id).maybeSingle(),
      supabase
        .from("employer_companies")
        .select("id")
        .eq("owner_id", user.id)
        .limit(1)
        .maybeSingle(),
    ]);

  return {
    userId: user.id,
    email: user.email ?? profile?.email ?? null,
    displayName: profile?.full_name ?? null,
    role: profile?.role ?? null,
    profileStatus: profile?.status ?? null,
    hasCandidateProfile: Boolean(candidate),
    hasEmployerProfile: Boolean(company),
  };
}

export const getPublicAccountNavigation = cache(async function getPublicAccountNavigation(): Promise<PublicAccountNavigation> {
  if (supabaseConfigError()) {
    return { authenticated: false, role: null, displayName: null, dashboardHref: null };
  }

  const snapshot = await getAuthenticatedAccountSnapshot();
  if (!snapshot.userId) {
    return { authenticated: false, role: null, displayName: null, dashboardHref: null };
  }

  const recovery = profileRecoveryDecision(snapshot);
  return {
    authenticated: true,
    role: snapshot.role,
    displayName: snapshot.displayName ?? snapshot.email,
    dashboardHref: recovery?.redirectTo ?? (snapshot.role ? dashboardForRole(snapshot.role) : routes.accountSetup),
  };
});

export async function getAuthenticatedProfile() {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return { user: null, profile: null };

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, role, full_name, email, status")
    .eq("id", user.id)
    .maybeSingle<ProfileRow>();

  return { user, profile };
}

export const requireRole = cache(async function requireRole(role: AppAccountRole): Promise<AccountContext> {
  const supabase = await createServerSupabaseClient();
  const currentPath = await currentPathFromHeaders();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    const loginRoute = role === "candidate" ? routes.candidateLogin : routes.employerLogin;
    redirect(`${loginRoute}?redirectTo=${encodeURIComponent(currentPath)}`);
  }

  const [{ data: profile }, { data: candidate }, { data: company }] =
    await Promise.all([
      supabase
        .from("profiles")
        .select("id, role, full_name, email, status")
        .eq("id", user.id)
        .maybeSingle<ProfileRow>(),
      supabase.from("candidate_profiles").select("id").eq("id", user.id).maybeSingle(),
      supabase
        .from("employer_companies")
        .select("id")
        .eq("owner_id", user.id)
        .limit(1)
        .maybeSingle(),
    ]);

  const snapshot: AccountSnapshot = {
    userId: user.id,
    email: user.email ?? profile?.email ?? null,
    displayName: profile?.full_name ?? null,
    role: profile?.role ?? null,
    profileStatus: profile?.status ?? null,
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
  };
});

export async function redirectAuthenticatedAuthPage({ allowMissingProfile = false }: { allowMissingProfile?: boolean } = {}) {
  const snapshot = await getAuthenticatedAccountSnapshot();
  if (allowMissingProfile && snapshot.userId && !snapshot.role) return;
  const decision = authPageDecision(snapshot);
  if (!decision.allowed && decision.redirectTo) redirect(decision.redirectTo);
}

export async function requireAccountSetup() {
  const snapshot = await getAuthenticatedAccountSnapshot();
  const decision = accountSetupDecision(snapshot);
  if (!decision.allowed && decision.redirectTo) redirect(decision.redirectTo);
  return snapshot;
}

export async function signOutAction() {
  "use server";

  const supabase = await createServerSupabaseClient();
  await supabase.auth.signOut({ scope: "local" });
  revalidatePath("/", "layout");
  redirect(`${routes.candidateLogin}?analytics=logout`);
}

export async function signOutToHomeAction() {
  "use server";

  const supabase = await createServerSupabaseClient();
  await supabase.auth.signOut({ scope: "local" });
  revalidatePath("/", "layout");
  redirect(`${routes.home}?analytics=logout`);
}

export async function loadCandidateDashboardData(userId: string) {
  const supabase = await createServerSupabaseClient();
  const [{ data: candidate }, { data: membership }] = await Promise.all([
    supabase
      .from("candidate_profiles")
      .select(
        "id, headline, nationality, current_country, current_city, preferred_country, preferred_city, job_categories, skills, languages, availability, is_visible, is_verified",
      )
      .eq("id", userId)
      .maybeSingle<CandidateProfileRow>(),
    supabase
      .from("candidate_memberships")
      .select("status, plan_code, membership_type, started_at, expires_at")
      .eq("candidate_id", userId)
      .order("updated_at", { ascending: false })
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
