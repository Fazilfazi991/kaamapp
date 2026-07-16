import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { MessageInbox } from "@/features/messaging/components/inbox";
import { loadConversationSummaries } from "@/features/messaging/server/data";

export default async function EmployerMessagesPage() {
  const conversations = await loadConversationSummaries("employer");
  return (
    <div className="grid gap-6">
      <PageTitle title="Messages" description="Chat access is available only for matches allowed by the existing backend rule." />
      {conversations.length ? (
        <MessageInbox conversations={conversations} />
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
