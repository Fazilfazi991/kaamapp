import { PageTitle } from "@/components/layout/page-title";
import { Button } from "@/components/ui/button";
import { submitEmployerVerification } from "@/features/employer/server/profile-actions";
import { loadEmployerCompanyBundle } from "@/features/employer/server/profile-data";
import { employerCompanyCompletion } from "@/features/employer/profile/completion";
import { employerCompanyLocationParts } from "@/features/employer/profile/validation";

export default async function EmployerReviewStepPage() {
  const { company, documents } = await loadEmployerCompanyBundle();
  const completion = employerCompanyCompletion(company, documents);
  return (
    <div className="grid gap-6">
      <PageTitle title="Optional business verification" description="Verification documents are optional and never control employer account access." />
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <h2 className="text-lg font-semibold text-[#201925]">{company?.company_name ?? "Company profile"}</h2>
        <p className="mt-2 text-sm text-[#66616f]">Location: {employerCompanyLocationParts(company?.country, company?.city, company?.office_area).join(", ") || "Not set"}</p>
        <p className="mt-2 text-sm text-[#66616f]">Company setup: {completion.percentage}% complete. Business verification is optional.</p>
        <form action={submitEmployerVerification} className="mt-5">
          <Button type="submit">Continue to dashboard</Button>
        </form>
      </section>
    </div>
  );
}
