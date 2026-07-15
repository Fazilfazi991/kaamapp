import { PageTitle } from "@/components/layout/page-title";
import { AuthNotice } from "@/components/ui/auth-notice";
import { EmployerDashboard } from "@/features/employer/employer-dashboard";
import { loadEmployerDashboardData, requireRole } from "@/lib/auth/session";

export default async function EmployerDashboardPage({
  searchParams,
}: {
  searchParams: Promise<{ authNotice?: string }>;
}) {
  const { userId } = await requireRole("employer");
  const { company } = await loadEmployerDashboardData(userId);
  const params = await searchParams;

  return (
    <div className="grid gap-6">
      <AuthNotice code={params.authNotice} />
      <PageTitle title="Employer dashboard" description="Company status, candidate search, shortlist, matches, and job posts." />
      <EmployerDashboard company={company} />
    </div>
  );
}
