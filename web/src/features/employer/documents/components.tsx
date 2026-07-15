import { Button, ButtonLink } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import { employerDocumentTypes } from "@/features/employer/documents/validation";
import { uploadEmployerDocument } from "@/features/employer/server/profile-actions";
import type { VerificationDocumentRow } from "@/features/employer/types";

export function documentLabel(type: string) {
  return employerDocumentTypes.find((item) => item.type === type)?.label ?? type;
}

export function DocumentUploadForm() {
  return (
    <form action={uploadEmployerDocument} className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <h2 className="text-lg font-semibold text-[#201925]">Upload business document</h2>
      <div className="mt-5 grid gap-4 md:grid-cols-2">
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">Document type<select name="documentType" className="focus-ring min-h-12 rounded-lg border border-[#dfd2d9] px-4">{employerDocumentTypes.map((item) => <option key={item.type} value={item.type}>{item.label}{item.required ? " (required)" : ""}</option>)}</select></label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">Choose from device<input type="file" name="documentFile" accept="image/jpeg,image/png,image/webp,application/pdf" className="min-h-12 rounded-lg border border-[#dfd2d9] px-4 py-3" /></label>
      </div>
      <p className="mt-3 text-sm text-[#66616f]">Use your device camera from the file picker when available. Documents are stored privately.</p>
      <div className="mt-5"><Button type="submit">Upload document</Button></div>
    </form>
  );
}

export function EmployerDocumentCards({ documents }: { documents: VerificationDocumentRow[] }) {
  return (
    <div className="grid gap-4">
      {employerDocumentTypes.map((type) => {
        const document = documents.find((item) => item.document_type === type.type);
        return (
          <article key={type.type} className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div><h2 className="text-lg font-semibold text-[#201925]">{type.label}</h2><p className="mt-1 text-sm text-[#66616f]">{type.required ? "Required" : "Optional"} business verification document.</p></div>
              <StatusBadge tone={document?.status === "approved" ? "success" : document ? "warning" : "neutral"}>{document?.status ?? "not_uploaded"}</StatusBadge>
            </div>
            <p className="mt-4 text-sm text-[#66616f]">Uploaded: {document ? new Date(document.created_at).toLocaleDateString() : "Not uploaded"}</p>
            <div className="mt-5 flex flex-wrap gap-3">
              {document ? <ButtonLink href={`/employer/documents/${document.id}`} variant="secondary">View</ButtonLink> : null}
              <ButtonLink href="/employer/documents/upload">{document ? "Replace / resubmit" : "Upload"}</ButtonLink>
            </div>
          </article>
        );
      })}
    </div>
  );
}
