import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default function EmployerMessagesPage() {
  return (
    <div className="grid gap-6">
      <PageTitle title="Messages" description="Employer chat will appear after match chat access is connected." />
      <EmptyStateCard title="No messages loaded" description="The web foundation does not display fabricated chat data." />
    </div>
  );
}
