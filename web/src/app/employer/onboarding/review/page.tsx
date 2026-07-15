import { PageTitle } from "@/components/layout/page-title";
import { Button } from "@/components/ui/button";
import { submitEmployerVerification } from "@/features/employer/server/profile-actions";
import { loadEmployerCompanyBundle } from "@/features/employer/server/profile-data";
import { employerCompanyCompletion } from "@/features/employer/profile/completion";

export default async function EmployerReviewStepPage() {
  const { company, documents } = await loadEmployerCompanyBundle();
  const completion = employerCompanyCompletion(company, documents);
  return (
    <div className="grid gap-6">
      <PageTitle title="Review and submit" description="Submission keeps documents pending for admin review; it does not approve the company." />
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <h2 className="text-lg font-semibold text-[#201925]">{company?.company_name ?? "Company profile"}</h2>
        <p className="mt-2 text-sm text-[#66616f]">Completion: {completion.percentage}% - Review status: {completion.reviewStatus}</p>
        <form action={submitEmployerVerification} className="mt-5">
          <Button type="submit">Submit for review</Button>
        </form>
      </section>
    </div>
  );
}
