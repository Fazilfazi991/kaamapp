import { PageTitle } from "@/components/layout/page-title";
import { AuthNotice } from "@/components/ui/auth-notice";
import { EmployerDashboard } from "@/features/employer/employer-dashboard";
import { loadEmployerDashboard } from "@/features/employer/server/data";

export default async function EmployerDashboardPage({
  searchParams,
}: {
  searchParams: Promise<{ authNotice?: string }>;
}) {
  const { access, counts, documents } = await loadEmployerDashboard();
  const params = await searchParams;

  return (
    <div className="grid gap-5">
      <AuthNotice code={params.authNotice} />
      <PageTitle title="Employer dashboard" description="Search candidates, send interest, match, and connect." />
      <EmployerDashboard access={access} counts={counts} documents={documents} />
    </div>
  );
}
