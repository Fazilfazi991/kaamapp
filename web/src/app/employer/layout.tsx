import { DashboardShell } from "@/components/layout/dashboard-shell";
import { employerNavigation } from "@/config/navigation";
import { requireRole } from "@/lib/auth/session";

export default async function EmployerLayout({ children }: { children: React.ReactNode }) {
  const account = await requireRole("employer");

  return (
    <DashboardShell
      account={{ email: account.email, role: account.role }}
      items={employerNavigation}
      title="Employer"
    >
      {children}
    </DashboardShell>
  );
}
