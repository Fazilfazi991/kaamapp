import { PageTitle } from "@/components/layout/page-title";
import { PassportCanonicalUploadForm } from "@/features/candidate/documents/components/passport-canonical-upload-form";

export default function CandidatePassportUploadPage() {
  return (
    <div className="grid gap-6">
      <PageTitle
        title="Upload passport"
        description="Take a passport photo or choose a clear image from your device."
      />
      <PassportCanonicalUploadForm />
    </div>
  );
}
