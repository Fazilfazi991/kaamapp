import { DashboardShell } from "@/components/layout/dashboard-shell";
import { candidateNavigation } from "@/config/navigation";
import { requireRole } from "@/lib/auth/session";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { candidateCompletion } from "@/features/candidate/profile-completion";
import type { CandidateProfileRow, ProfileRow } from "@/types/domain";

export default async function CandidateLayout({ children }: { children: React.ReactNode }) {
  const account = await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const [{ data: profile }, { data: candidate }] = await Promise.all([
    supabase
      .from("profiles")
      .select("full_name,phone")
      .eq("id", account.userId)
      .maybeSingle<Pick<ProfileRow, "full_name" | "phone">>(),
    supabase.from("candidate_profiles").select("headline,nationality,current_country,current_city,preferred_country,preferred_city,job_categories,skills,availability").eq("id", account.userId).maybeSingle<CandidateProfileRow>(),
  ]);
  const profileComplete = candidateCompletion({
    profile,
    candidate,
  }).isComplete;

  return (
    <DashboardShell
      account={{ email: account.email, role: account.role, name: profile?.full_name }}
      items={candidateNavigation({ profileComplete })}
      title="Candidate"
    >
      {children}
    </DashboardShell>
  );
}
