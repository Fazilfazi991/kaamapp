import { EmptyStateCard } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { ButtonLink } from "@/components/ui/button";
import { routes } from "@/config/routes";
import { employerCompanyCompletion } from "@/features/employer/profile/completion";
import type { EmployerAccess } from "@/features/employer/server/access";
import type { VerificationDocumentRow } from "./types";

export function EmployerDashboard({ access, counts, documents = [] }: {
  access: EmployerAccess;
  counts: { shortlisted: number; interestsSent: number; matches: number } | null;
  documents?: VerificationDocumentRow[];
}) {
  const company = access.ok ? access.company : null;
  const completion = employerCompanyCompletion(company, documents);

  return <div className="grid gap-6">
    <section className="rounded-xl border border-[#eadde3] bg-white p-5 shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-[#201925]">{completion.isComplete ? "Employer profile ready" : "Complete your Employer setup"}</h2>
          <p className="mt-1 text-sm text-[#66616f]">{completion.isComplete ? "Your company details are ready for the KAAM hiring workspace." : "Add company details, location, and a contact person. Business verification remains contextual and optional."}</p>
        </div>
        <StatusBadge tone={company?.is_verified ? "success" : "neutral"}>{company?.is_verified ? "Business verified" : "Optional verification"}</StatusBadge>
      </div>
      {!access.ok ? <p className="mt-4 text-sm text-[#9a1744]">{access.message}</p> : null}
      {access.ok && access.warning ? <p className="mt-4 text-sm text-[#66616f]">{access.warning}</p> : null}
      {!completion.isComplete ? <div className="mt-4 grid gap-1 text-sm text-[#3b3340] sm:grid-cols-3"><span>Company details: {completion.infoComplete ? "Complete" : "Needed"}</span><span>Location: {completion.locationComplete ? "Complete" : "Needed"}</span><span>Contact: {completion.contactComplete ? "Complete" : "Needed"}</span></div> : null}
      <div className="mt-5 flex flex-wrap gap-3">
        {!completion.isComplete ? <ButtonLink href={routes.employerOnboarding}>Continue setup</ButtonLink> : null}
        <ButtonLink href={routes.employerSearch} variant={completion.isComplete ? "primary" : "secondary"}>Search Candidates</ButtonLink>
      </div>
    </section>

    <section><h2 className="text-base font-semibold text-[#201925]">Quick actions</h2><div className="mt-3 flex flex-wrap gap-3"><ButtonLink href={routes.employerSearch}>Search Candidates</ButtonLink><ButtonLink href={routes.employerInterests} variant="secondary">View Interests</ButtonLink><ButtonLink href={routes.employerMatches} variant="secondary">View Matches</ButtonLink></div></section>

    <section><h2 className="text-base font-semibold text-[#201925]">Hiring overview</h2><div className="mt-3 grid gap-4 md:grid-cols-3">
      {[["Interests sent", counts?.interestsSent ?? 0, routes.employerInterests], ["Matches", counts?.matches ?? 0, routes.employerMatches], ["Saved candidates", counts?.shortlisted ?? 0, routes.employerShortlist]].map(([label, value, href]) => <section key={label} className="rounded-xl border border-[#eadde3] bg-white p-5 shadow-sm"><p className="text-sm font-semibold text-[#66616f]">{label}</p><p className="mt-2 text-3xl font-bold text-[#201925]">{value}</p><ButtonLink href={String(href)} variant="ghost" className="mt-3 min-h-0 px-0 py-0">Open</ButtonLink></section>)}
    </div></section>

    <div className="grid gap-4 md:grid-cols-2">
      <EmptyStateCard title="Candidate search" description="Search visible candidates through the existing safe public candidate-search view." actionHref={routes.employerSearch} actionLabel="Search candidates" />
      <EmptyStateCard title="Business verification" description={company?.is_verified ? "Your optional business verification is complete." : "Trade licence and business verification are optional and managed contextually in Employer setup."} actionHref="/employer/onboarding/documents" actionLabel={company?.is_verified ? "View verification" : "Complete verification"} />
    </div>
  </div>;
}
