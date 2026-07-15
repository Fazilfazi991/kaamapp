import { PageTitle } from "@/components/layout/page-title";
import { CompanyContactForm } from "@/features/employer/profile/forms";
import { loadEmployerCompanyBundle } from "@/features/employer/server/profile-data";

export default async function EmployerContactStepPage() {
  const { company } = await loadEmployerCompanyBundle();
  return (
    <div className="grid gap-6">
      <PageTitle title="Employer contact" description="Save the contact person shown internally for employer account management." />
      <CompanyContactForm company={company} />
    </div>
  );
}
