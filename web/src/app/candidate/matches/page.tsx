import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { CandidateMatchCard } from "@/features/candidate/interests/components/candidate-match-card";
import { loadCandidateMatches } from "@/features/candidate/interests/server/data";

export default async function CandidateMatchesPage() {
  const { matches, error } = await loadCandidateMatches();
  return (
    <div className="grid gap-6">
      <PageTitle title="Matches" description="Accepted employer interests and contact-sharing status." />
      {error ? <EmptyStateCard title="Could not load matches" description={error} /> : null}
      {matches.length ? (
        <div className="grid gap-4">
          {matches.map((match) => (
            <CandidateMatchCard key={match.match_id} match={match} />
          ))}
        </div>
      ) : (
        <EmptyStateCard
          title="No active matches"
          description="Matches appear after you accept an employer interest request."
          actionHref="/candidate/interests"
          actionLabel="View interests"
        />
      )}
    </div>
  );
}
