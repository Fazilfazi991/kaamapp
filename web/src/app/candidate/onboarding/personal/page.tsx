import { routes } from "@/config/routes";
import { FormCard } from "@/features/candidate/components/form-card";
import { OnboardingShell } from "@/features/candidate/components/onboarding-shell";
import { PersonalForm } from "@/features/candidate/components/personal-form";
import { loadCandidateBundle } from "@/features/candidate/server/data";

export default async function CandidateOnboardingPersonalPage() {
  const bundle = await loadCandidateBundle();
  return (
    <OnboardingShell
      current={routes.candidateOnboardingPersonal}
      title="Personal details"
      description="Add the minimum details employers need to understand your profile."
    >
      <FormCard>
        <PersonalForm profile={bundle.profile} candidate={bundle.candidate} />
      </FormCard>
    </OnboardingShell>
  );
}
