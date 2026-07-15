import { DashboardShell } from "@/components/layout/dashboard-shell";
import { candidateNavigation } from "@/config/navigation";
import { requireRole } from "@/lib/auth/session";

export default async function CandidateLayout({ children }: { children: React.ReactNode }) {
  await requireRole("candidate");

  return (
    <DashboardShell items={candidateNavigation} title="Candidate">
      {children}
    </DashboardShell>
  );
}
