import { DashboardShell } from "@/components/layout/dashboard-shell";
import { employerNavigation } from "@/config/navigation";
import { requireRole } from "@/lib/auth/session";

export default async function EmployerLayout({ children }: { children: React.ReactNode }) {
  await requireRole("employer");

  return (
    <DashboardShell items={employerNavigation} title="Employer">
      {children}
    </DashboardShell>
  );
}
