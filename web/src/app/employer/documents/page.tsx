import { PageTitle } from "@/components/layout/page-title";
import { EmployerDocumentCards } from "@/features/employer/documents/components";
import { loadEmployerCompanyBundle } from "@/features/employer/server/profile-data";

export default async function EmployerDocumentsPage() {
  const { documents } = await loadEmployerCompanyBundle();
  return (
    <div className="grid gap-6">
      <PageTitle title="Employer documents" description="Private business documents submitted for KAAM review." />
      <EmployerDocumentCards documents={documents} />
    </div>
  );
}
