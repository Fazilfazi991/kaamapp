import { AdminPageHeader, AdminStatCard, DetailSection } from "@/features/admin/components/admin-ui";
import { loadAdminDashboardMetrics } from "@/features/admin/server/data";

export default async function AdminPage() {
  const metrics = await loadAdminDashboardMetrics();

  return (
    <>
      <AdminPageHeader
        title="Admin overview"
        description="Operational review queues for Kaam profiles, verification documents, account status, and moderation gaps supported by the current Supabase schema."
      />
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <AdminStatCard label="Total candidates" value={metrics.totalCandidates} />
        <AdminStatCard label="Total employers" value={metrics.totalEmployers} />
        <AdminStatCard label="Pending candidate documents" value={metrics.pendingCandidateDocuments} />
        <AdminStatCard label="Pending employer documents" value={metrics.pendingEmployerDocuments} />
        <AdminStatCard label="Approved candidate documents" value={metrics.approvedCandidateDocs} />
        <AdminStatCard label="Rejected candidate documents" value={metrics.rejectedCandidateDocs} />
        <AdminStatCard label="Active users" value={metrics.activeUsers} />
        <AdminStatCard label="Blocked users" value={metrics.blockedUsers} />
        <AdminStatCard label="Recent matches" value={metrics.recentMatches} />
      </div>
      <DetailSection title="Backend limits">
        <p>
          The current schema has no general report table, admin audit table, reviewer ID columns, or separate employer
          rejection reason field. Those features are shown transparently where relevant and are not simulated in browser state.
        </p>
      </DetailSection>
    </>
  );
}
