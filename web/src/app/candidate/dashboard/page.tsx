import { PageTitle } from "@/components/layout/page-title";
import { CandidateDashboard } from "@/features/candidate/candidate-dashboard";
import { loadCandidateDashboardData, requireRole } from "@/lib/auth/session";

export default async function CandidateDashboardPage() {
  const { user } = await requireRole("candidate");
  const { candidate, membership } = await loadCandidateDashboardData(user.id);

  return (
    <div className="grid gap-6">
      <PageTitle
        title="Candidate dashboard"
        description="Your profile, verification, matching, and membership status in one place."
      />
      <CandidateDashboard candidate={candidate} membership={membership} />
    </div>
  );
}
