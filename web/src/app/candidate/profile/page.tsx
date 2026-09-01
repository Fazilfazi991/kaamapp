import { ProfileSummary } from "@/features/candidate/components/profile-summary";
import { loadCandidateBundle } from "@/features/candidate/server/data";
import { loadCandidateDocuments } from "@/features/candidate/documents/server/data";

export default async function CandidateProfilePage() {
  const [bundle, documents] = await Promise.all([loadCandidateBundle(), loadCandidateDocuments()]);
  const passport = documents.cards.find((card) => card.type === "passport");
  return (
    <ProfileSummary
      profile={bundle.profile}
      candidate={bundle.candidate}
      membership={bundle.membership}
      hasProfileDocument={Boolean(passport?.hasFile)}
    />
  );
}
