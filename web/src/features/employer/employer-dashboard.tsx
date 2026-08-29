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

  return <div className="grid gap-5">
    <section className="rounded-2xl border border-[#e7e1f2] bg-white p-4 shadow-[0_8px_22px_rgba(22,8,71,.06)] sm:p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-bold text-[#160847]">{completion.isComplete ? "Employer profile ready" : "Complete your Employer setup"}</h2>
          <p className="mt-1 text-sm leading-5 text-[#66616f]">{completion.isComplete ? "Your company profile is ready for hiring." : "Add company details, location, and a contact person to start hiring."}</p>
        </div>
        <StatusBadge tone={company?.is_verified ? "success" : "neutral"}>{company?.is_verified ? "Business verified" : "Optional verification"}</StatusBadge>
      </div>
      {!access.ok ? <p className="mt-3 text-sm text-[#9a1744]">{access.message}</p> : null}
      {access.ok && access.warning ? <p className="mt-3 text-sm text-[#66616f]">{access.warning}</p> : null}
      {!completion.isComplete ? <div className="mt-3 grid gap-1 rounded-xl bg-[#faf9ff] px-3 py-2 text-xs text-[#514856] sm:grid-cols-3"><span>Company: {completion.infoComplete ? "Complete" : "Needed"}</span><span>Location: {completion.locationComplete ? "Complete" : "Needed"}</span><span>Contact: {completion.contactComplete ? "Complete" : "Needed"}</span></div> : null}
      <div className="mt-4 flex flex-wrap gap-2.5">
        {!completion.isComplete ? <ButtonLink href={routes.employerOnboarding}>Continue setup</ButtonLink> : null}
        <ButtonLink href={routes.employerSearch} variant={completion.isComplete ? "primary" : "secondary"}>Search Candidates</ButtonLink>
      </div>
    </section>

    <section><h2 className="text-base font-bold text-[#160847]">Quick actions</h2><div className="mt-2.5 grid gap-2.5 sm:grid-cols-3"><ButtonLink href={routes.employerSearch} className="min-h-11 px-4 py-2.5">Search Candidates</ButtonLink><ButtonLink href={routes.employerInterests} variant="secondary" className="min-h-11 px-4 py-2.5">View Interests</ButtonLink><ButtonLink href={routes.employerMatches} variant="secondary" className="min-h-11 px-4 py-2.5">View Matches</ButtonLink></div></section>

    <section><h2 className="text-base font-bold text-[#160847]">Hiring overview</h2><div className="mt-2.5 grid gap-3 md:grid-cols-3">
      {[["Interests sent", counts?.interestsSent ?? 0, routes.employerInterests], ["Matches", counts?.matches ?? 0, routes.employerMatches], ["Saved candidates", counts?.shortlisted ?? 0, routes.employerShortlist]].map(([label, value, href]) => <section key={label} className="rounded-2xl border border-[#e7e1f2] bg-white px-4 py-3.5 shadow-[0_6px_16px_rgba(22,8,71,.05)]"><p className="text-sm font-semibold text-[#66616f]">{label}</p><p className="mt-1 text-3xl font-bold leading-none text-[#160847]">{value}</p><ButtonLink href={String(href)} variant="ghost" className="mt-1.5 min-h-0 px-0 py-0 text-xs">View →</ButtonLink></section>)}
    </div></section>

    <div className="grid gap-3 md:grid-cols-2">
      <EmptyStateCard title="Candidate search" description="Search visible candidates through the existing safe public candidate-search view." actionHref={routes.employerSearch} actionLabel="Search candidates" />
      <EmptyStateCard title="Business verification" description={company?.is_verified ? "Your optional business verification is complete." : "Trade licence and business verification are optional and managed contextually in Employer setup."} actionHref="/employer/onboarding/documents" actionLabel={company?.is_verified ? "View verification" : "Complete verification"} />
    </div>
  </div>;
}
