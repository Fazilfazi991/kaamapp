import { routes } from "@/config/routes";
import { FormCard } from "@/features/candidate/components/form-card";
import { LocationForm } from "@/features/candidate/components/location-form";
import { OnboardingShell } from "@/features/candidate/components/onboarding-shell";
import { loadCandidateLocationData } from "@/features/candidate/server/data";

export default async function CandidateOnboardingLocationPage() {
  const { candidate } = await loadCandidateLocationData();
  return (
    <OnboardingShell
      current={routes.candidateOnboardingLocation}
      title="Location"
      description="Set your current residence and choose where in the GCC you prefer to work."
    >
      <FormCard>
        <LocationForm
          currentCountry={candidate?.current_country}
          currentRegion={candidate?.current_city}
          preferredCountry={candidate?.preferred_country}
          preferredRegion={candidate?.preferred_city}
        />
      </FormCard>
    </OnboardingShell>
  );
}
