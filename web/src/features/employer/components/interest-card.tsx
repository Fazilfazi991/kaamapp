import { Button, ButtonLink } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import { withdrawInterest } from "@/features/employer/server/actions";
import { candidateDisplayId, interestStatusLabel, interestTone } from "@/features/employer/utils";
import type { InterestRow, PublicCandidateSearchRow } from "@/features/employer/types";

export function InterestCard({
  interest,
  candidate,
}: {
  interest: InterestRow;
  candidate?: PublicCandidateSearchRow;
}) {
  return (
    <article className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-[#201925]">
            {candidate?.full_name || candidateDisplayId(interest.candidate_id)}
          </h2>
          <p className="mt-1 text-sm text-[#66616f]">
            {candidate?.headline || "Candidate"} · sent {new Date(interest.created_at).toLocaleDateString()}
          </p>
        </div>
        <StatusBadge tone={interestTone(interest.status)}>{interestStatusLabel(interest.status)}</StatusBadge>
      </div>
      <p className="mt-4 text-sm leading-6 text-[#66616f]">
        Contact details remain private until the existing match and candidate reveal rules allow access.
      </p>
      <div className="mt-5 flex flex-wrap gap-3">
        <ButtonLink href={`/employer/candidates/${interest.candidate_id}`} variant="secondary">
          View profile
        </ButtonLink>
        {interest.status === "pending" ? (
          <form action={withdrawInterest}>
            <input type="hidden" name="interestId" value={interest.id} />
            <Button type="submit" variant="ghost">
              Withdraw
            </Button>
          </form>
        ) : null}
        {interest.status === "accepted" ? (
          <ButtonLink href="/employer/matches">Open match</ButtonLink>
        ) : null}
      </div>
    </article>
  );
}
