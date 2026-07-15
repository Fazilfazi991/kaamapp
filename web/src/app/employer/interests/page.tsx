import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { InterestCard } from "@/features/employer/components/interest-card";
import { loadEmployerInterests } from "@/features/employer/server/data";

export default async function EmployerInterestsPage() {
  const { rows, candidatesById } = await loadEmployerInterests();
  return (
    <div className="grid gap-6">
      <PageTitle
        title="Interests"
        description="Employer-sent interest requests using the existing interest_requests table."
      />
      {rows.length ? (
        <div className="grid gap-4">
          {rows.map((interest) => (
            <InterestCard
              key={interest.id}
              interest={interest}
              candidate={candidatesById.get(interest.candidate_id)}
            />
          ))}
        </div>
      ) : (
        <EmptyStateCard
          title="No interests sent"
          description="Send interest from a candidate profile. A match is created only after the candidate accepts."
          actionHref="/employer/search"
          actionLabel="Search candidates"
        />
      )}
    </div>
  );
}
