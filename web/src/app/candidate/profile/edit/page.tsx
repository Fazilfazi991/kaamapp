import { routes } from "@/config/routes";
import { ExperienceForm } from "@/features/candidate/components/experience-form";
import { FormCard } from "@/features/candidate/components/form-card";
import { LocationForm } from "@/features/candidate/components/location-form";
import { PersonalForm } from "@/features/candidate/components/personal-form";
import { SkillsForm } from "@/features/candidate/components/skills-form";
import { loadCandidateBundle } from "@/features/candidate/server/data";

export default async function CandidateProfileEditPage() {
  const bundle = await loadCandidateBundle();
  return (
    <div className="grid gap-6">
      <div>
        <h1 className="text-2xl font-bold text-[#201925]">Edit Profile</h1>
        <p className="mt-2 text-sm text-[#66616f]">
          Update one section at a time. Saved values from other sections are preserved.
        </p>
      </div>
      <FormCard>
        <h2 className="mb-4 text-lg font-semibold text-[#201925]">Personal details</h2>
        <PersonalForm
          profile={bundle.profile}
          candidate={bundle.candidate}
          next={routes.candidateProfile}
        />
      </FormCard>
      <FormCard>
        <h2 className="mb-4 text-lg font-semibold text-[#201925]">Skills</h2>
        <SkillsForm
          categories={bundle.categories}
          skills={bundle.skills}
          selectedSkills={bundle.selectedSkills}
          next={routes.candidateProfile}
        />
      </FormCard>
      <FormCard>
        <h2 className="mb-4 text-lg font-semibold text-[#201925]">Location</h2>
        <LocationForm
          currentCountry={bundle.candidate?.current_country}
          currentRegion={bundle.candidate?.current_city}
          preferredCountry={bundle.candidate?.preferred_country}
          preferredRegion={bundle.candidate?.preferred_city}
          next={routes.candidateProfile}
        />
      </FormCard>
      <FormCard>
        <h2 className="mb-4 text-lg font-semibold text-[#201925]">Experience and privacy</h2>
        <ExperienceForm candidate={bundle.candidate} next={routes.candidateProfile} />
      </FormCard>
    </div>
  );
}
