import { AuthNotice } from "@/components/ui/auth-notice";
import { CandidateDashboard } from "@/features/candidate/candidate-dashboard";
import { loadCandidateDashboardCounts } from "@/features/candidate/interests/server/data";
import { loadCandidateBundle } from "@/features/candidate/server/data";
import { loadCandidateDocuments } from "@/features/candidate/documents/server/data";
import { requireRole } from "@/lib/auth/session";

export default async function CandidateDashboardPage({
  searchParams,
}: {
  searchParams: Promise<{ authNotice?: string }>;
}) {
  await requireRole("candidate");
  const [{ profile, candidate, membership }, counts, documents] = await Promise.all([
    loadCandidateBundle(),
    loadCandidateDashboardCounts(),
    loadCandidateDocuments(),
  ]);
  const params = await searchParams;

  const passport = documents.cards.find((card) => card.type === "passport");

  return (
    <div className="grid gap-4">
      <AuthNotice code={params.authNotice} />
      <CandidateDashboard
        profile={profile}
        candidate={candidate}
        membership={membership}
        counts={counts}
        hasPassport={Boolean(passport?.hasFile)}
        passportStatus={passport?.status ?? "not_uploaded"}
      />
    </div>
  );
}
