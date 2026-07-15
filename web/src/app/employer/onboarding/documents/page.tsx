import { PageTitle } from "@/components/layout/page-title";
import { ButtonLink } from "@/components/ui/button";
import { EmployerDocumentCards } from "@/features/employer/documents/components";
import { loadEmployerCompanyBundle } from "@/features/employer/server/profile-data";

export default async function EmployerDocumentsStepPage() {
  const { documents } = await loadEmployerCompanyBundle();
  return (
    <div className="grid gap-6">
      <PageTitle title="Verification documents" description="Upload required private business documents for review." />
      <EmployerDocumentCards documents={documents} />
      <ButtonLink href="/employer/onboarding/review" variant="secondary">Continue to review</ButtonLink>
    </div>
  );
}
