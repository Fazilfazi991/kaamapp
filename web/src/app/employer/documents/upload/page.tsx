import { PageTitle } from "@/components/layout/page-title";
import { DocumentUploadForm } from "@/features/employer/documents/components";

export default function EmployerDocumentUploadPage() {
  return (
    <div className="grid gap-6">
      <PageTitle title="Upload employer document" description="Upload private business verification files. Supported: images and PDF." />
      <DocumentUploadForm />
    </div>
  );
}
