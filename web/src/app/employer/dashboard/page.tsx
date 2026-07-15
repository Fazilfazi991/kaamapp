import { PageTitle } from "@/components/layout/page-title";
import { EmployerDashboard } from "@/features/employer/employer-dashboard";
import { loadEmployerDashboardData, requireRole } from "@/lib/auth/session";

export default async function EmployerDashboardPage() {
  const { user } = await requireRole("employer");
  const { company } = await loadEmployerDashboardData(user.id);

  return (
    <div className="grid gap-6">
      <PageTitle title="Employer dashboard" description="Company status, candidate search, shortlist, matches, and job posts." />
      <EmployerDashboard company={company} />
    </div>
  );
}
