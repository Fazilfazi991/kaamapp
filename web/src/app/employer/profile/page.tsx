import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default function EmployerProfilePage() {
  return (
    <div className="grid gap-6">
      <PageTitle title="Company Profile" description="Company profile editing will connect to existing employer company records." />
      <EmptyStateCard title="Company editor not enabled" description="Use the mobile app for complete employer onboarding until this web flow is connected." />
    </div>
  );
}
