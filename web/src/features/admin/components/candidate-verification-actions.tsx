import { Button } from "@/components/ui/button";
import { rejectCandidateVerification, requireCandidateReverification, verifyCandidate } from "@/features/admin/server/actions";

export function CandidateVerificationActions({
  candidateId,
  canVerify,
  blockers,
}: {
  candidateId: string;
  canVerify: boolean;
  blockers: string[];
}) {
  return (
    <div className="grid gap-4 border-t border-[#f0e4eb] pt-4">
      {!canVerify ? (
        <div className="rounded-lg bg-[#fff8e8] p-3 text-sm text-[#725400]">
          <p className="font-semibold">Candidate cannot be verified yet</p>
          <ul className="mt-1 list-disc pl-5">{blockers.map((blocker) => <li key={blocker}>{blocker}</li>)}</ul>
        </div>
      ) : null}
      <form action={verifyCandidate} className="grid gap-2 sm:grid-cols-[1fr_auto]">
        <input type="hidden" name="candidateId" value={candidateId} />
        <input name="notes" maxLength={500} placeholder="Optional verification notes" className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 text-sm" />
        <Button type="submit" disabled={!canVerify}>Verify Candidate</Button>
      </form>
      <div className="grid gap-3 md:grid-cols-2">
        <form action={rejectCandidateVerification} className="grid gap-2">
          <input type="hidden" name="candidateId" value={candidateId} />
          <textarea name="reason" required minLength={6} maxLength={500} placeholder="Reason for rejecting verification" className="focus-ring min-h-24 rounded-lg border border-[#ded2da] p-3 text-sm" />
          <Button type="submit" variant="secondary">Reject Verification</Button>
        </form>
        <form action={requireCandidateReverification} className="grid gap-2">
          <input type="hidden" name="candidateId" value={candidateId} />
          <textarea name="reason" required minLength={6} maxLength={500} placeholder="Reason reverification is required" className="focus-ring min-h-24 rounded-lg border border-[#ded2da] p-3 text-sm" />
          <Button type="submit" variant="secondary">Require Reverification</Button>
        </form>
      </div>
    </div>
  );
}
