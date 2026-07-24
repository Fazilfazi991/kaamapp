import { CandidateAvatar } from "@/components/ui/candidate-avatar";
import { Button, ButtonLink } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import { interestStatusLabel, interestTone } from "@/features/employer/utils";
import {
  removeShortlistCandidate,
  sendInterest,
  shortlistCandidate,
} from "@/features/employer/server/actions";
import type { EmployerCandidateCardModel } from "@/features/employer/types";

export async function EmployerCandidateCard({ candidate }: { candidate: EmployerCandidateCardModel }) {
  return (
    <article className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <div className="flex gap-4">
        <CandidateAvatar path={candidate.profilePhotoUrl} name={candidate.displayName} size={64} />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="text-lg font-semibold text-[#201925]">{candidate.displayName}</h2>
            {candidate.isVerified ? <StatusBadge tone="success">Identity verified</StatusBadge> : null}
            {candidate.interestStatus ? (
              <StatusBadge tone={interestTone(candidate.interestStatus)}>
                {interestStatusLabel(candidate.interestStatus)}
              </StatusBadge>
            ) : null}
          </div>
          <p className="mt-1 text-sm font-semibold text-[#3b3340]">{candidate.headline}</p>
          <p className="mt-1 text-sm text-[#66616f]">{candidate.location}</p>
        </div>
      </div>

      <dl className="mt-4 grid gap-3 text-sm md:grid-cols-3">
        <div>
          <dt className="font-semibold text-[#3b3340]">Availability</dt>
          <dd className="mt-1 text-[#66616f]">{candidate.availability}</dd>
        </div>
        <div>
          <dt className="font-semibold text-[#3b3340]">Experience</dt>
          <dd className="mt-1 text-[#66616f]">{candidate.experience}</dd>
        </div>
        <div>
          <dt className="font-semibold text-[#3b3340]">Expected salary</dt>
          <dd className="mt-1 text-[#66616f]">{candidate.expectedSalary}</dd>
        </div>
      </dl>

      <div className="mt-4 flex flex-wrap gap-2">
        {candidate.skills.map((skill) => (
          <span key={skill} className="rounded-full bg-[#f7f2f5] px-3 py-1 text-xs font-semibold text-[#3b3340]">
            {skill}
          </span>
        ))}
      </div>

      <div className="mt-5 flex flex-wrap gap-3">
        <ButtonLink href={`/employer/candidates/${candidate.id}`} variant="secondary">
          View profile
        </ButtonLink>
        <form action={candidate.isShortlisted ? removeShortlistCandidate : shortlistCandidate}>
          <input type="hidden" name="candidateId" value={candidate.id} />
          <Button type="submit" variant="ghost">
            {candidate.isShortlisted ? "Remove shortlist" : "Add shortlist"}
          </Button>
        </form>
        {candidate.interestStatus || candidate.isMatched ? (
          <ButtonLink href="/employer/interests" variant="ghost">
            View interest status
          </ButtonLink>
        ) : (
          <form action={sendInterest}>
            <input type="hidden" name="candidateId" value={candidate.id} />
            <Button type="submit">Send interest</Button>
          </form>
        )}
      </div>
    </article>
  );
}
