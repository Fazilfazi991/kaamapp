import { PageTitle } from "@/components/layout/page-title";
import { CompanyInformationForm } from "@/features/employer/profile/forms";
import { loadEmployerCompanyBundle } from "@/features/employer/server/profile-data";

export default async function EmployerCompanyStepPage() {
  const { company } = await loadEmployerCompanyBundle();
  return (
    <div className="grid gap-6">
      <PageTitle title="Company information" description="Save legal company details supported by the existing employer profile schema." />
      <CompanyInformationForm company={company} />
    </div>
  );
}
