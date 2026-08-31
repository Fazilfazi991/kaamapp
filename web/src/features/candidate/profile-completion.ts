import { routes } from "@/config/routes";
import { validateCurrentResidence, validatePreferredWorkLocation } from "@/features/candidate/validation";
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
  requirePhone = false,
}: {
  profile: Pick<ProfileRow, "full_name" | "phone"> | null;
  candidate: CandidateProfileRow | null;
  requirePhone?: boolean;
}) {
  const sections: CompletionSection[] = [
    {
      id: "personal",
      label: "Personal details",
      href: routes.candidateOnboardingPersonal,
      complete:
        hasText(profile?.full_name) &&
        (!requirePhone || hasText(profile?.phone)) &&
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
        validateCurrentResidence(candidate?.current_country ?? "", candidate?.current_city ?? "").ok &&
        validatePreferredWorkLocation(candidate?.preferred_country ?? "", candidate?.preferred_city ?? "").ok,
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
