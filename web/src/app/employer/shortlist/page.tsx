import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { EmployerCandidateCard } from "@/features/employer/components/candidate-card";
import { loadShortlist } from "@/features/employer/server/data";

export default async function EmployerShortlistPage() {
  const { candidates } = await loadShortlist();
  return (
    <div className="grid gap-6">
      <PageTitle title="Saved Candidates" description="Candidates saved from the existing saved-candidates backend table." />
      {candidates.length ? (
        <div className="grid gap-4">
          {candidates.map((candidate) => (
            <EmployerCandidateCard key={candidate.id} candidate={candidate} />
          ))}
        </div>
      ) : (
        <EmptyStateCard
          title="No saved candidates"
          description="Saving a candidate keeps their profile handy and does not create a match."
          actionHref="/employer/search"
          actionLabel="Search candidates"
        />
      )}
    </div>
  );
}
