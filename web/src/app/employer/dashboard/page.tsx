import { PageTitle } from "@/components/layout/page-title";
import { AuthNotice } from "@/components/ui/auth-notice";
import { EmployerDashboard } from "@/features/employer/employer-dashboard";
import { loadEmployerDashboardSummary } from "@/features/employer/server/data";
import { loadEmployerCompanyBundle } from "@/features/employer/server/profile-data";

export default async function EmployerDashboardPage({
  searchParams,
}: {
  searchParams: Promise<{ authNotice?: string }>;
}) {
  const [{ access, counts }, { documents }] = await Promise.all([
    loadEmployerDashboardSummary(),
    loadEmployerCompanyBundle(),
  ]);
  const params = await searchParams;

  return (
    <div className="grid gap-6">
      <AuthNotice code={params.authNotice} />
      <PageTitle title="Employer dashboard" description="Company status, candidate search, shortlist, matches, and job posts." />
      <EmployerDashboard access={access} counts={counts} documents={documents} />
    </div>
  );
}
