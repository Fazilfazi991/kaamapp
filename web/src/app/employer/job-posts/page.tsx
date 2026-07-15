import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default function EmployerJobPostsPage() {
  return (
    <div className="grid gap-6">
      <PageTitle title="Job Posts" description="Hiring requirements and job-posting workflows will be connected in a later phase." />
      <EmptyStateCard title="No job posts loaded" description="Employer pricing and membership plans are intentionally not included." />
    </div>
  );
}
