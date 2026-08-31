import { ProfileSummary } from "@/features/candidate/components/profile-summary";
import { loadCandidateBundle } from "@/features/candidate/server/data";

export default async function CandidateProfilePage() {
  const bundle = await loadCandidateBundle();
  return (
    <ProfileSummary
      profile={bundle.profile}
      candidate={bundle.candidate}
      membership={bundle.membership}
    />
  );
}
