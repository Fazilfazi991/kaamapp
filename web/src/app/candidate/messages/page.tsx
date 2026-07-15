import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default function CandidateMessagesPage() {
  return (
    <div className="grid gap-6">
      <PageTitle title="Messages" description="Conversations will appear only after the existing match chat access rules are connected." />
      <EmptyStateCard title="No messages loaded" description="Chat data is not fabricated in the web foundation." />
    </div>
  );
}
