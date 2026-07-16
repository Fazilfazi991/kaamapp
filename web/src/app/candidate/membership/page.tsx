import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default function CandidateMembershipPage() {
  return (
    <div className="grid gap-6">
      <PageTitle title="Membership" description="Candidate membership visibility is read from the existing Supabase membership table." />
      <EmptyStateCard title="Membership plans not editable on web yet" description="The web foundation can display membership state on the dashboard, but activation and payment workflows are intentionally left incomplete." />
    </div>
  );
}
