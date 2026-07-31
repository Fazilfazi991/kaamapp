import { notFound } from "next/navigation";
import { secureDocumentPreviewKind } from "@/components/documents/preview-kind";
import { SecureDocumentViewer } from "@/components/documents/secure-document-viewer";
import { AdminPageHeader, AdminStatus, DetailSection, Field } from "@/features/admin/components/admin-ui";
import { EmployerDocumentReviewActions } from "@/features/admin/components/employer-review-actions";
import { loadEmployerDocument } from "@/features/admin/server/data";
import { getEmployerDocumentReviewState } from "@/features/admin/validation/review";

export default async function AdminEmployerDocumentDetailPage({ params }: { params: Promise<{ documentId: string }> }) {
  const { documentId } = await params;
  const document = await loadEmployerDocument(documentId);
  if (!document) notFound();
  const reviewState = getEmployerDocumentReviewState(document);
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
        <SecureDocumentViewer
          documentKey={document.id}
          kind={secureDocumentPreviewKind(document.file_path)}
          previewUrl={`/admin/employer-documents/preview/${document.id}`}
          title={`${document.document_type} document preview`}
        />
      </DetailSection>
      <DetailSection title="Review action">
        <p>{reviewState.message}</p>
        <EmployerDocumentReviewActions
          documentId={document.id}
          companyId={document.company_id}
          canApprove={reviewState.canApprove}
          canRequestResubmission={reviewState.canRequestResubmission}
        />
      </DetailSection>
    </>
  );
}
