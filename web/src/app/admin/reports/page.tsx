import { AdminPageHeader, DetailSection } from "@/features/admin/components/admin-ui";

export default function AdminReportsPage() {
  return (
    <>
      <AdminPageHeader title="Reports" description="Moderation reports are not yet backed by a Supabase report or abuse table in the current schema." />
      <DetailSection title="Moderation status">
        <p>No report queue can be implemented securely until a backend reports table, RLS policies, and resolution workflow exist.</p>
      </DetailSection>
    </>
  );
}
