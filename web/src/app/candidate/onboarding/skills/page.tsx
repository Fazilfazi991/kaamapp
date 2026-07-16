import { routes } from "@/config/routes";
import { FormCard } from "@/features/candidate/components/form-card";
import { OnboardingShell } from "@/features/candidate/components/onboarding-shell";
import { SkillsForm } from "@/features/candidate/components/skills-form";
import { loadCandidateBundle } from "@/features/candidate/server/data";

export default async function CandidateOnboardingSkillsPage() {
  const bundle = await loadCandidateBundle();
  return (
    <OnboardingShell
      current={routes.candidateOnboardingSkills}
      title="Skills"
      description="Choose one main category, then select up to three related skills."
    >
      <FormCard>
        <SkillsForm
          categories={bundle.categories}
          skills={bundle.skills}
          selectedSkills={bundle.selectedSkills}
        />
      </FormCard>
    </OnboardingShell>
  );
}
