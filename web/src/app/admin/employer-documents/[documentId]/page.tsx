import { notFound } from "next/navigation";
import { Button } from "@/components/ui/button";
import { approveEmployerDocument, rejectEmployerDocument } from "@/features/admin/server/actions";
import { AdminPageHeader, AdminStatus, DetailSection, Field } from "@/features/admin/components/admin-ui";
import { loadEmployerDocument } from "@/features/admin/server/data";

export default async function AdminEmployerDocumentDetailPage({ params }: { params: Promise<{ documentId: string }> }) {
  const { documentId } = await params;
  const document = await loadEmployerDocument(documentId);
  if (!document) notFound();
  return (
    <>
      <AdminPageHeader title={document.document_type} description="Employer document preview and review action. Company approval is a separate explicit action." />
      <DetailSection title="Document summary">
        <div className="grid gap-4 md:grid-cols-3">
          <Field label="Company" value={document.employer_companies?.company_name} />
          <Field label="Location" value={[document.employer_companies?.city, document.employer_companies?.country].filter(Boolean).join(", ")} />
          <Field label="Status" value={<AdminStatus status={document.status} />} />
          <Field label="Submitted" value={document.created_at?.slice(0, 10)} />
          <Field label="Updated" value={document.updated_at?.slice(0, 10)} />
        </div>
      </DetailSection>
      <DetailSection title="Private preview">
        <iframe title="Employer document preview" src={`/admin/employer-documents/preview/${document.id}`} className="h-[520px] w-full rounded-lg border border-[#eadde3]" />
      </DetailSection>
      <DetailSection title="Review action">
        <div className="grid gap-3 md:grid-cols-2">
          <form action={approveEmployerDocument}>
            <input type="hidden" name="documentId" value={document.id} />
            <Button type="submit" className="w-full">Approve document</Button>
          </form>
          <form action={rejectEmployerDocument} className="grid gap-3">
            <input type="hidden" name="documentId" value={document.id} />
            <label className="text-sm font-semibold text-[#201925]" htmlFor="reason">Public rejection reason</label>
            <textarea id="reason" name="reason" required className="focus-ring min-h-24 rounded-lg border border-[#ded2da] p-3 text-sm" />
            <Button type="submit" variant="secondary">Request resubmission</Button>
          </form>
        </div>
      </DetailSection>
    </>
  );
}
