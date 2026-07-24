import { Button } from "@/components/ui/button";
import { NavigationLink } from "@/components/layout/navigation-progress";
import { routes } from "@/config/routes";
import { OnboardingShell } from "@/features/candidate/components/onboarding-shell";
import { ProfileSummary } from "@/features/candidate/components/profile-summary";
import { candidateCompletion } from "@/features/candidate/profile-completion";
import { finishCandidateOnboarding } from "@/features/candidate/server/actions";
import { loadCandidateBundle } from "@/features/candidate/server/data";

export default async function CandidateOnboardingReviewPage() {
  const bundle = await loadCandidateBundle();
  const completion = candidateCompletion({
    profile: bundle.profile,
    candidate: bundle.candidate,
  });
  return (
    <OnboardingShell
      current={routes.candidateOnboardingReview}
      title="Review profile"
      description="Check your saved details before opening your dashboard."
    >
      {!completion.isComplete ? (
        <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
          <h2 className="text-lg font-semibold text-[#201925]">
            Missing sections
          </h2>
          <div className="mt-3 flex flex-wrap gap-2">
            {completion.missingSections.map((section) => (
              <NavigationLink
                key={section.id}
                href={section.href}
                className="rounded-full bg-[#fff0f5] px-3 py-2 text-sm font-semibold text-[#bc1f55]"
              >
                {section.label}
              </NavigationLink>
            ))}
          </div>
        </section>
      ) : null}
      <ProfileSummary
        profile={bundle.profile}
        candidate={bundle.candidate}
        membership={bundle.membership}
      />
      <form action={finishCandidateOnboarding}>
        <Button type="submit" disabled={!completion.isComplete}>
          Finish and open dashboard
        </Button>
      </form>
    </OnboardingShell>
  );
}
