import { routes } from "@/config/routes";
import type { CandidateProfileRow, ProfileRow } from "@/types/domain";

export type CompletionSection = {
  id: "personal" | "skills" | "location" | "experience";
  label: string;
  complete: boolean;
  href: string;
};

function hasText(value?: string | null) {
  return Boolean(value?.trim());
}

export function candidateCompletion({
  profile,
  candidate,
}: {
  profile: Pick<ProfileRow, "full_name" | "phone"> | null;
  candidate: CandidateProfileRow | null;
}) {
  const sections: CompletionSection[] = [
    {
      id: "personal",
      label: "Personal details",
      href: routes.candidateOnboardingPersonal,
      complete:
        hasText(profile?.full_name) &&
        hasText(profile?.phone) &&
        hasText(candidate?.nationality),
    },
    {
      id: "skills",
      label: "Skills",
      href: routes.candidateOnboardingSkills,
      complete:
        (candidate?.skills?.length ?? 0) > 0 &&
        hasText(candidate?.headline) &&
        (candidate?.job_categories?.length ?? 0) > 0,
    },
    {
      id: "location",
      label: "Location",
      href: routes.candidateOnboardingLocation,
      complete:
        hasText(candidate?.current_country) &&
        hasText(candidate?.current_city) &&
        hasText(candidate?.preferred_country) &&
        hasText(candidate?.preferred_city),
    },
    {
      id: "experience",
      label: "Experience",
      href: routes.candidateOnboardingExperience,
      complete: hasText(candidate?.availability),
    },
  ];
  const completed = sections.filter((section) => section.complete).length;
  const percentage = Math.round((completed / sections.length) * 100);
  const missingSections = sections.filter((section) => !section.complete);

  return {
    sections,
    percentage,
    missingSections,
    nextHref: missingSections[0]?.href ?? routes.candidateOnboardingReview,
    isComplete: missingSections.length === 0,
  };
}
