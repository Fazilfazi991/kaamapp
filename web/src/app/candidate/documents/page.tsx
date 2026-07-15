import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default function CandidateDocumentsPage() {
  return (
    <div className="grid gap-6">
      <PageTitle title="Documents" description="Document upload and OCR remain in the existing mobile app flow during this foundation phase." />
      <EmptyStateCard title="Document web upload not enabled" description="This avoids duplicating passport, Emirates ID, visa, and storage behavior before the web upload flow is explicitly scoped." />
    </div>
  );
}
