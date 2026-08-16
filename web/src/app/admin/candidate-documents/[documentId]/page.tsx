import { notFound } from "next/navigation";
import { Button } from "@/components/ui/button";
import { secureDocumentPreviewKind } from "@/components/documents/preview-kind";
import { SecureDocumentViewer } from "@/components/documents/secure-document-viewer";
import { approveCandidateDocument, rejectCandidateDocument } from "@/features/admin/server/actions";
import { AdminPageHeader, AdminStatus, DetailSection, Field } from "@/features/admin/components/admin-ui";
import { loadCandidateDocument } from "@/features/admin/server/data";
import { getCandidateDocumentReviewState } from "@/features/admin/validation/review";

export default async function AdminCandidateDocumentDetailPage({ params }: { params: Promise<{ documentId: string }> }) {
  const { documentId } = await params;
  const document = await loadCandidateDocument(documentId);
  if (!document) notFound();
  const reviewState = getCandidateDocumentReviewState(document);
  const previewUrl = `/admin/candidate-documents/preview/${document.id}`;
  const passportFrontPath = document.file_paths?.front ?? document.file_path;
  const passportBackPath = document.file_paths?.back;

  return (
    <>
      <AdminPageHeader title={`${document.document_type} document`} description="Private preview is generated server-side from this document ID only and expires quickly." />
      <DetailSection title="Candidate identity summary">
        <div className="grid gap-4 md:grid-cols-3">
          <Field label="Candidate" value={document.candidate_profiles?.profiles?.full_name} />
          <Field label="Email" value={document.candidate_profiles?.profiles?.email} />
          <Field label="Location" value={[document.candidate_profiles?.current_city, document.candidate_profiles?.current_country].filter(Boolean).join(", ")} />
          <Field label="Status" value={<AdminStatus status={document.status} />} />
          <Field label="Version" value={document.version_number} />
          <Field label="Source" value={document.source === "summary" ? "Summary fallback" : document.is_historical ? "Historical version" : "Version"} />
          <Field label="Submitted" value={document.created_at?.slice(0, 10)} />
          <Field label="Expiry" value={document.expiry_date} />
        </div>
      </DetailSection>
      <DetailSection title="Private preview">
        {document.document_type === "passport" ? (
          <div className="grid gap-6 lg:grid-cols-2">
            <div className="grid gap-3">
              <h3 className="font-semibold">Current Passport Front</h3>
              <SecureDocumentViewer
                documentKey={`${document.id}-front`}
                kind={secureDocumentPreviewKind(passportFrontPath)}
                previewUrl={passportFrontPath ? `${previewUrl}?side=front` : null}
                title="Current Passport Front"
              />
            </div>
            <div className="grid gap-3">
              <h3 className="font-semibold">Current Passport Back</h3>
              <SecureDocumentViewer
                documentKey={`${document.id}-back`}
                kind={secureDocumentPreviewKind(passportBackPath)}
                previewUrl={passportBackPath ? `${previewUrl}?side=back` : null}
                title="Current Passport Back"
              />
            </div>
          </div>
        ) : (
          <SecureDocumentViewer
            documentKey={document.id}
            kind={secureDocumentPreviewKind(document.file_path)}
            previewUrl={document.file_path ? previewUrl : null}
            title={`${document.document_type} document preview`}
          />
        )}
      </DetailSection>
      <DetailSection title="Review action">
        <p>{reviewState.message}</p>
        {reviewState.canApprove || reviewState.canRequestResubmission ? (
          <div className="grid gap-3 md:grid-cols-2">
            <form action={approveCandidateDocument}>
              <input type="hidden" name="documentId" value={document.id} />
              <Button type="submit" className="w-full">Approve</Button>
            </form>
            <form action={rejectCandidateDocument} className="grid gap-3">
              <input type="hidden" name="documentId" value={document.id} />
              <label className="text-sm font-semibold text-[#201925]" htmlFor="reason">Public rejection reason</label>
              <textarea id="reason" name="reason" required className="focus-ring min-h-24 rounded-lg border border-[#ded2da] p-3 text-sm" />
              <Button type="submit" variant="secondary">Request resubmission</Button>
            </form>
          </div>
        ) : null}
      </DetailSection>
    </>
  );
}
