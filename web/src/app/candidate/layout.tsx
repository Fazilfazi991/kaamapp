import { DashboardShell } from "@/components/layout/dashboard-shell";
import { candidateNavigation } from "@/config/navigation";
import { requireRole } from "@/lib/auth/session";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { candidateCompletion } from "@/features/candidate/profile-completion";
import type { CandidateProfileRow, ProfileRow } from "@/types/domain";

export default async function CandidateLayout({ children }: { children: React.ReactNode }) {
  const account = await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const [{ data: profile }, { data: candidate }, { data: documents }] = await Promise.all([
    supabase
      .from("profiles")
      .select("full_name,phone")
      .eq("id", account.userId)
      .maybeSingle<Pick<ProfileRow, "full_name" | "phone">>(),
    supabase.from("candidate_profiles").select("*").eq("id", account.userId).maybeSingle<CandidateProfileRow>(),
    supabase.from("candidate_documents").select("passport_file_url").eq("candidate_id", account.userId).maybeSingle<{ passport_file_url: string | null }>(),
  ]);
  const profileComplete = candidateCompletion({
    profile,
    candidate,
    hasPassport: Boolean(documents?.passport_file_url?.trim()),
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
