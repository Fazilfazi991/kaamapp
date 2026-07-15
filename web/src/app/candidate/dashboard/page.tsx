import { PageTitle } from "@/components/layout/page-title";
import { AuthNotice } from "@/components/ui/auth-notice";
import { CandidateDashboard } from "@/features/candidate/candidate-dashboard";
import { loadCandidateDashboardData, requireRole } from "@/lib/auth/session";

export default async function CandidateDashboardPage({
  searchParams,
}: {
  searchParams: Promise<{ authNotice?: string }>;
}) {
  const { userId } = await requireRole("candidate");
  const { candidate, membership } = await loadCandidateDashboardData(userId);
  const params = await searchParams;

  return (
    <div className="grid gap-6">
      <AuthNotice code={params.authNotice} />
      <PageTitle
        title="Candidate dashboard"
        description="Your profile, verification, matching, and membership status in one place."
      />
      <CandidateDashboard candidate={candidate} membership={membership} />
    </div>
  );
}
