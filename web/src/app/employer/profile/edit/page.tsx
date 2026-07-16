import { PageTitle } from "@/components/layout/page-title";
import { CompanyContactForm, CompanyInformationForm, CompanyLocationForm, CompanyLogoForm } from "@/features/employer/profile/forms";
import { loadEmployerCompanyBundle } from "@/features/employer/server/profile-data";

export default async function EmployerProfileEditPage() {
  const { company } = await loadEmployerCompanyBundle();
  return (
    <div className="grid gap-6">
      <PageTitle title="Edit company profile" description="Update supported company profile fields without changing admin approval directly." />
      <CompanyInformationForm company={company} next="/employer/profile" />
      <CompanyLocationForm company={company} next="/employer/profile" />
      <CompanyContactForm company={company} next="/employer/profile" />
      <CompanyLogoForm />
    </div>
  );
}
