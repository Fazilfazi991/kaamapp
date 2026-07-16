import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { MatchCard } from "@/features/employer/components/match-card";
import { loadEmployerMatches } from "@/features/employer/server/data";

export default async function EmployerMatchesPage() {
  const { matches, error } = await loadEmployerMatches();
  return (
    <div className="grid gap-6">
      <PageTitle
        title="Matches"
        description="Accepted interests and contact access from the existing match/contact RPC."
      />
      {error ? <EmptyStateCard title="Could not load matches" description={error} /> : null}
      {matches.length ? (
        <div className="grid gap-4">
          {matches.map((match) => (
            <MatchCard key={match.match_id} match={match} />
          ))}
        </div>
      ) : (
        <EmptyStateCard
          title="No active matches"
          description="Matches appear here after a candidate accepts your interest request."
          actionHref="/employer/interests"
          actionLabel="View interests"
        />
      )}
    </div>
  );
}
