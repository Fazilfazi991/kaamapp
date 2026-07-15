import { routes } from "@/config/routes";
import { ExperienceForm } from "@/features/candidate/components/experience-form";
import { FormCard } from "@/features/candidate/components/form-card";
import { OnboardingShell } from "@/features/candidate/components/onboarding-shell";
import { loadCandidateBundle } from "@/features/candidate/server/data";

export default async function CandidateOnboardingExperiencePage() {
  const { candidate } = await loadCandidateBundle();
  return (
    <OnboardingShell
      current={routes.candidateOnboardingExperience}
      title="Experience and availability"
      description="Tell employers when you can join and how much experience you have."
    >
      <FormCard>
        <ExperienceForm candidate={candidate} />
      </FormCard>
    </OnboardingShell>
  );
}
