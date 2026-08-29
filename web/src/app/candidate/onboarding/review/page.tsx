import { routes } from "@/config/routes";
import { FinishOnboardingButton } from "@/features/candidate/components/finish-onboarding-button";
import { OnboardingShell } from "@/features/candidate/components/onboarding-shell";
import { ProfileSummary } from "@/features/candidate/components/profile-summary";
import { candidateCompletion } from "@/features/candidate/profile-completion";
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
              <a
                key={section.id}
                href={section.href}
                className="rounded-full bg-[#fff0f5] px-3 py-2 text-sm font-semibold text-[#bc1f55]"
              >
                {section.label}
              </a>
            ))}
          </div>
        </section>
      ) : null}
      <ProfileSummary
        profile={bundle.profile}
        candidate={bundle.candidate}
        membership={bundle.membership}
      />
      <FinishOnboardingButton disabled={!completion.isComplete} />
    </OnboardingShell>
  );
}
