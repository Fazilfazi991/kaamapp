import { DashboardShell } from "@/components/layout/dashboard-shell";
import { candidateNavigation } from "@/config/navigation";
import { routes } from "@/config/routes";
import { loadCandidateCoreData } from "@/lib/auth/session";
import { candidateCompletion } from "@/features/candidate/profile-completion";
import { headers } from "next/headers";

export default async function CandidateLayout({ children }: { children: React.ReactNode }) {
  const currentPath = (await headers()).get("x-current-path") ?? "";
  const { account, profile, candidate } = await loadCandidateCoreData();
  const profileComplete = candidateCompletion({
    profile,
    candidate,
  }).isComplete;

  return (
    <DashboardShell
      account={{ email: account.email, role: account.role, name: profile?.full_name }}
      items={candidateNavigation({ profileComplete, onboarding: currentPath.startsWith(routes.candidateOnboarding) })}
      title="Candidate"
    >
      {children}
    </DashboardShell>
  );
}
