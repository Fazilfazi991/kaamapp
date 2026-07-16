import { notFound } from "next/navigation";
import { PageTitle } from "@/components/layout/page-title";
import { CandidateInterestCard } from "@/features/candidate/interests/components/interest-card";
import { loadCandidateInterest } from "@/features/candidate/interests/server/data";

export default async function CandidateInterestDetailsPage({
  params,
}: {
  params: Promise<{ interestId: string }>;
}) {
  const { interestId } = await params;
  const interest = await loadCandidateInterest(interestId);
  if (!interest) notFound();
  return (
    <div className="grid gap-6">
      <PageTitle
        title="Interest details"
        description="Accepting this interest creates a match through the existing backend trigger."
      />
      <CandidateInterestCard interest={interest} detailed />
    </div>
  );
}
