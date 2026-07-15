import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default function CandidateProfilePage() {
  return (
    <div className="grid gap-6">
      <PageTitle title="Profile" description="Candidate profile editing will connect to the existing profile tables in a later phase." />
      <EmptyStateCard title="Profile editor not enabled" description="No fake candidate profile data is shown here. Use the mobile app for full profile editing until this web flow is connected." />
    </div>
  );
}
