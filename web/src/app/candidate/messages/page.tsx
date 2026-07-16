import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { MessageInbox } from "@/features/messaging/components/inbox";
import { loadConversationSummaries } from "@/features/messaging/server/data";

export default async function CandidateMessagesPage() {
  const conversations = await loadConversationSummaries("candidate");
  return (
    <div className="grid gap-6">
      <PageTitle title="Messages" description="Matched employer conversations authorized by the existing chat rules." />
      {conversations.length ? (
        <MessageInbox conversations={conversations} />
      ) : (
        <EmptyStateCard
          title="No conversations"
          description="Conversations appear after an accepted match allows messaging."
          actionHref="/candidate/matches"
          actionLabel="View matches"
        />
      )}
    </div>
  );
}
