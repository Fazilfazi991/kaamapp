import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { MatchCard } from "@/features/employer/components/match-card";
import { loadEmployerMatches } from "@/features/employer/server/data";

export default async function EmployerMessagesPage() {
  const { matches } = await loadEmployerMatches();
  const chatEnabled = matches.filter((match) => match.chat_enabled);
  return (
    <div className="grid gap-6">
      <PageTitle title="Messages" description="Chat access is available only for matches allowed by the existing backend rule." />
      {chatEnabled.length ? (
        <div className="grid gap-4">
          {chatEnabled.map((match) => (
            <MatchCard key={match.match_id} match={match} />
          ))}
        </div>
      ) : (
        <EmptyStateCard
          title="No available chats"
          description="Unmatched employers cannot message candidates. Chat appears after a valid match with backend access."
          actionHref="/employer/matches"
          actionLabel="View matches"
        />
      )}
    </div>
  );
}
