import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { ButtonLink } from "@/components/ui/button";
import { EmployerCandidateCard } from "@/features/employer/components/candidate-card";
import { EmployerSearchForm } from "@/features/employer/components/search-form";
import { filtersToSearchParams } from "@/features/employer/search/filters";
import { loadEmployerSearch } from "@/features/employer/server/data";

export default async function EmployerSearchPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  const { access, filters, lookups, results, searchError, total, totalPages } = await loadEmployerSearch(params);

  return (
    <div className="grid gap-6">
      <PageTitle
        title="Search candidates"
        description="Find visible, verified candidates using the existing safe candidate-search backend."
      />
      {access.warning ? (
        <section className="rounded-lg border border-[#eadde3] bg-[#fffafc] p-4 text-sm text-[#66616f]">
          {access.warning}
        </section>
      ) : null}
      <EmployerSearchForm filters={filters} lookups={lookups} />
      {searchError ? <EmptyStateCard title="Search unavailable" description={searchError} /> : null}
      <div className="flex flex-wrap items-center justify-between gap-3 text-sm text-[#66616f]">
        <span>{total} candidate{total === 1 ? "" : "s"} found</span>
        <span>Page {filters.page} of {totalPages}</span>
      </div>
      {results.length ? (
        <div className="grid gap-4">
          {results.map((candidate) => (
            <EmployerCandidateCard key={candidate.id} candidate={candidate} />
          ))}
        </div>
      ) : (
        <EmptyStateCard
          title="No candidates found"
          description="Try clearing filters or broadening the category, location, or availability."
        />
      )}
      <div className="flex flex-wrap justify-between gap-3">
        {filters.page > 1 ? (
          <ButtonLink href={`/employer/search?${filtersToSearchParams(filters, { page: filters.page - 1 })}`} variant="secondary">
            Previous
          </ButtonLink>
        ) : <span />}
        {filters.page < totalPages ? (
          <ButtonLink href={`/employer/search?${filtersToSearchParams(filters, { page: filters.page + 1 })}`} variant="secondary">
            Next
          </ButtonLink>
        ) : null}
      </div>
    </div>
  );
}
