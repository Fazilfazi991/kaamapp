import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { routes } from "@/config/routes";
import type {
  CandidateMembershipRow,
  CandidateProfileRow,
  EmployerCompanyRow,
  ProfileRow,
  UserRole,
} from "@/types/domain";

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

export async function requireRole(role: Exclude<UserRole, "admin">) {
  const { user, profile } = await getAuthenticatedProfile();

  if (!user) redirect(routes.login);
  if (!profile) redirect(routes.register);

  if (profile.role !== role) {
    if (profile.role === "admin") redirect(routes.admin);
    redirect(
      profile.role === "candidate"
        ? routes.candidateDashboard
        : routes.employerDashboard,
    );
  }

  return { user, profile };
}

export async function signOutAction() {
  "use server";

  const supabase = await createServerSupabaseClient();
  await supabase.auth.signOut();
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
