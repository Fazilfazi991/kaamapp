import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { EmployerCandidateCard } from "@/features/employer/components/candidate-card";
import { loadShortlist } from "@/features/employer/server/data";

export default async function EmployerShortlistPage() {
  const { candidates } = await loadShortlist();
  return (
    <div className="grid gap-6">
      <PageTitle title="Shortlist" description="Candidates saved from the existing saved-candidates backend table." />
      {candidates.length ? (
        <div className="grid gap-4">
          {candidates.map((candidate) => (
            <EmployerCandidateCard key={candidate.id} candidate={candidate} />
          ))}
        </div>
      ) : (
        <EmptyStateCard
          title="No shortlisted candidates"
          description="Shortlisting keeps candidates private and does not create a match."
          actionHref="/employer/search"
          actionLabel="Search candidates"
        />
      )}
    </div>
  );
}
