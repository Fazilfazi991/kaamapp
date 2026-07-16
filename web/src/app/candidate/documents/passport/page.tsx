import { PageTitle } from "@/components/layout/page-title";
import { DocumentUploadForm } from "@/features/candidate/documents/components/document-upload-form";
import { uploadPassportDocument } from "@/features/candidate/documents/server/actions";

export default function CandidatePassportUploadPage() {
  return (
    <div className="grid gap-6">
      <PageTitle
        title="Upload passport"
        description="Take a passport photo or choose a clear image from your device."
      />
      <DocumentUploadForm
        type="passport"
        title="Passport image"
        description="JPG, PNG, or WebP images up to 10 MB are accepted for OCR-assisted review."
        action={uploadPassportDocument}
      />
    </div>
  );
}
