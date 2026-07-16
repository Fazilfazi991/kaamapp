import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { CandidateInterestCard } from "@/features/candidate/interests/components/interest-card";
import { loadCandidateInterests } from "@/features/candidate/interests/server/data";

export default async function CandidateInterestsPage() {
  const { interests, error } = await loadCandidateInterests();
  return (
    <div className="grid gap-6">
      <PageTitle
        title="Employer interests"
        description="Review employer interest requests and respond using the existing match workflow."
      />
      {error ? <EmptyStateCard title="Could not load interests" description={error} /> : null}
      {interests.length ? (
        <div className="grid gap-4">
          {interests.map((interest) => (
            <CandidateInterestCard key={interest.id} interest={interest} />
          ))}
        </div>
      ) : (
        <EmptyStateCard
          title="No employer interests"
          description="Employer requests will appear here when verified employers send interest."
        />
      )}
    </div>
  );
}
