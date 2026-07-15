import { EmptyStateCard } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { ButtonLink } from "@/components/ui/button";
import { routes } from "@/config/routes";
import type { EmployerCompanyRow } from "@/types/domain";

export function EmployerDashboard({ company }: { company: EmployerCompanyRow | null }) {
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
                ? [company.industry, company.city, company.country].filter(Boolean).join(" • ")
                : "Create a company profile before contacting candidates."}
            </p>
          </div>
          <StatusBadge tone={company?.is_verified ? "success" : "warning"}>
            {company?.is_verified ? "Verified" : "Review pending"}
          </StatusBadge>
        </div>
      </section>

      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <h2 className="text-lg font-semibold text-[#201925]">Candidate search</h2>
        <p className="mt-2 text-sm leading-6 text-[#66616f]">
          Search filters are ready for UAE and India hiring flows. Results are kept as an empty state until the existing query contract is finalized for web.
        </p>
        <ButtonLink href={routes.employerSearch} className="mt-4">
          Search candidates
        </ButtonLink>
      </section>

      <div className="grid gap-4 md:grid-cols-2">
        <EmptyStateCard
          title="Recent interests"
          description="No employer interest records are displayed yet in the web foundation."
        />
        <EmptyStateCard
          title="Matches"
          description="Matched candidate conversations will be connected after the existing chat access rules are confirmed."
        />
      </div>

      <EmptyStateCard
        title="Shortlisted candidates"
        description="Shortlist data will appear here after the saved-candidates flow is wired for web."
        actionHref={routes.employerShortlist}
        actionLabel="Open shortlist"
      />
    </div>
  );
}
