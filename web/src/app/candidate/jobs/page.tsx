import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default function CandidateJobsPage() {
  return (
    <div className="grid gap-6">
      <PageTitle title="Jobs" description="Matched and recommended jobs will appear here after the query contract is finalized." />
      <EmptyStateCard title="No jobs loaded" description="This screen is a structured placeholder and does not fabricate production job records." />
    </div>
  );
}
