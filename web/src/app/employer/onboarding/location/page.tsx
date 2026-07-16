import { PageTitle } from "@/components/layout/page-title";
import { CompanyLocationForm } from "@/features/employer/profile/forms";
import { loadEmployerCompanyBundle } from "@/features/employer/server/profile-data";

export default async function EmployerLocationStepPage() {
  const { company } = await loadEmployerCompanyBundle();
  return (
    <div className="grid gap-6">
      <PageTitle title="Company location" description="Set the country and region for your company profile." />
      <CompanyLocationForm company={company} />
    </div>
  );
}
