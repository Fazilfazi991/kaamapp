import { PageTitle } from "@/components/layout/page-title";
import { ButtonLink } from "@/components/ui/button";
import { loadEmployerCompanyBundle } from "@/features/employer/server/profile-data";
import { employerCompanyCompletion, nextEmployerOnboardingPath } from "@/features/employer/profile/completion";

export default async function EmployerOnboardingPage() {
  const { company, documents } = await loadEmployerCompanyBundle();
  const completion = employerCompanyCompletion(company, documents);
  const next = nextEmployerOnboardingPath(company, documents);
  return (
    <div className="grid gap-6">
      <PageTitle title="Employer setup" description="Manage the company information used by the KAAM employer workspace." />
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <h2 className="text-lg font-semibold text-[#201925]">Setup progress</h2>
        <p className="mt-2 text-sm text-[#66616f]">{completion.percentage}% complete. Profile setup is separate from optional business verification.</p>
        <div className="mt-5 grid gap-2 text-sm text-[#3b3340]">
          <p>Company information: {completion.infoComplete ? "Complete" : "Incomplete"}</p>
          <p>Location: {completion.locationComplete ? "Complete" : "Incomplete"}</p>
          <p>Contact: {completion.contactComplete ? "Complete" : "Incomplete"}</p>
          <p>Verification: {company?.is_verified ? "Business verified" : "Optional"}</p>
        </div>
        <div className="mt-5 flex flex-wrap gap-3"><ButtonLink href={next}>Continue setup</ButtonLink><ButtonLink href="/employer/onboarding/documents" variant="secondary">Business verification</ButtonLink></div>
      </section>
    </div>
  );
}
