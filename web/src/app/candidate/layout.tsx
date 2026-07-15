import { DashboardShell } from "@/components/layout/dashboard-shell";
import { candidateNavigation } from "@/config/navigation";
import { requireRole } from "@/lib/auth/session";

export default async function CandidateLayout({ children }: { children: React.ReactNode }) {
  const account = await requireRole("candidate");

  return (
    <DashboardShell
      account={{ email: account.email, role: account.role }}
      items={candidateNavigation}
      title="Candidate"
    >
      {children}
    </DashboardShell>
  );
}
