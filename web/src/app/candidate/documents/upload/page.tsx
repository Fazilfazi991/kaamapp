import { PageTitle } from "@/components/layout/page-title";
import { DocumentUploadForm } from "@/features/candidate/documents/components/document-upload-form";
import {
  uploadPassportDocument,
  uploadVisaDocument,
} from "@/features/candidate/documents/server/actions";

export default function CandidateDocumentUploadPage() {
  return (
    <div className="grid gap-6">
      <PageTitle
        title="Upload documents"
        description="Choose the document type and add a photo or existing file."
      />
      <DocumentUploadForm
        type="passport"
        title="Passport"
        description="Use a clear passport image so the OCR review can read the details."
        action={uploadPassportDocument}
      />
      <DocumentUploadForm
        type="visa"
        title="Visa / Emirates ID support"
        description="Upload a visa or supporting identity file. PDF is supported for this document type."
        action={uploadVisaDocument}
      />
    </div>
  );
}
