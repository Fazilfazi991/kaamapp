import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default function EmployerShortlistPage() {
  return (
    <div className="grid gap-6">
      <PageTitle title="Shortlist" description="Saved candidates will use the existing saved-candidates backend table." />
      <EmptyStateCard title="No shortlisted candidates loaded" description="Shortlist records are not mocked in this web foundation." />
    </div>
  );
}
