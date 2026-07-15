import { EmptyStateCard } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { ButtonLink } from "@/components/ui/button";
import { routes } from "@/config/routes";
import { employerCompanyCompletion } from "@/features/employer/profile/completion";
import type { EmployerAccess } from "@/features/employer/server/access";
import type { VerificationDocumentRow } from "./types";

export function EmployerDashboard({
  access,
  counts,
  documents = [],
}: {
  access: EmployerAccess;
  counts: {
    shortlisted: number;
    pendingInterests: number;
    acceptedInterests: number;
    matches: number;
  } | null;
  documents?: VerificationDocumentRow[];
}) {
  const company = access.ok ? access.company : null;
  const completion = employerCompanyCompletion(company, documents);
  return (
    <div className="grid gap-5">
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold text-[#201925]">
              {company?.company_name ?? "Company profile"}
            </h2>
            <p className="mt-1 text-sm text-[#66616f]">
              {company
                ? [company.industry, company.city, company.country].filter(Boolean).join(" - ")
                : "Create a company profile before contacting candidates."}
            </p>
          </div>
          <StatusBadge tone={company?.is_verified ? "success" : "warning"}>
            {company?.is_verified ? "Verified" : "Review pending"}
          </StatusBadge>
        </div>
        {!access.ok ? (
          <p className="mt-4 text-sm text-[#9a1744]">{access.message}</p>
        ) : access.warning ? (
          <p className="mt-4 text-sm text-[#66616f]">{access.warning}</p>
        ) : null}
        <p className="mt-4 text-sm text-[#3b3340]">
          Profile completion: {completion.percentage}% - Documents: {completion.documentsComplete ? "Uploaded" : "Required"}
        </p>
        <div className="mt-5">
          <ButtonLink href={completion.isComplete ? routes.employerSearch : routes.employerOnboarding}>
            {completion.isComplete ? "Search Candidates" : "Complete Company Profile"}
          </ButtonLink>
        </div>
      </section>

      <div className="grid gap-4 md:grid-cols-4">
        {[
          ["Shortlisted", counts?.shortlisted ?? 0, routes.employerShortlist],
          ["Pending interests", counts?.pendingInterests ?? 0, routes.employerInterests],
          ["Accepted interests", counts?.acceptedInterests ?? 0, routes.employerInterests],
          ["Matches", counts?.matches ?? 0, routes.employerMatches],
        ].map(([label, value, href]) => (
          <section key={label} className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
            <p className="text-sm font-semibold text-[#66616f]">{label}</p>
            <p className="mt-2 text-3xl font-bold text-[#201925]">{value}</p>
            <ButtonLink href={String(href)} variant="ghost" className="mt-3 min-h-0 px-0 py-0">
              Open
            </ButtonLink>
          </section>
        ))}
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <EmptyStateCard
          title="Candidate search"
          description="Search visible candidates through the existing safe public candidate search view."
          actionHref={routes.employerSearch}
          actionLabel="Search candidates"
        />
        <EmptyStateCard
          title="Messages"
          description="Chat is available only when the existing match chat rule permits it."
          actionHref={routes.employerMessages}
          actionLabel="Open messages"
        />
      </div>
    </div>
  );
}
