import { AdminPageHeader, DetailSection } from "@/features/admin/components/admin-ui";

export default function AdminAuditPage() {
  return (
    <>
      <AdminPageHeader title="Audit" description="The current schema has candidate document notifications and version history, but no general admin audit table." />
      <DetailSection title="Audit status">
        <p>Approval/rejection history is visible from document statuses and candidate notifications where supported. A full immutable admin audit log requires a proposed migration and was not fabricated client-side.</p>
      </DetailSection>
    </>
  );
}
