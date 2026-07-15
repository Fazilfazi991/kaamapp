import { redirect } from "next/navigation";
import { candidateCompletion } from "@/features/candidate/profile-completion";
import { loadCandidateBundle } from "@/features/candidate/server/data";
import { routes } from "@/config/routes";

export default async function CandidateOnboardingIndexPage() {
  const bundle = await loadCandidateBundle();
  const completion = candidateCompletion({
    profile: bundle.profile,
    candidate: bundle.candidate,
  });
  redirect(completion.isComplete ? routes.candidateDashboard : completion.nextHref);
}
