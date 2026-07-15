import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default function CandidateMatchesPage() {
  return (
    <div className="grid gap-6">
      <PageTitle title="Matches" description="Employer matches will use the existing matching and contact access rules." />
      <EmptyStateCard title="No matches displayed" description="Match records are intentionally not mocked in this phase." />
    </div>
  );
}
