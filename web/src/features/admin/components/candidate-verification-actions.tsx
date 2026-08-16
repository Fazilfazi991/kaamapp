"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { Button } from "@/components/ui/button";
import { rejectCandidateVerification, requireCandidateReverification, verifyCandidate } from "@/features/admin/server/actions";
import { initialAdminActionState } from "@/features/admin/validation/review";

function SubmitButton({ children, disabled = false }: { children: React.ReactNode; disabled?: boolean }) {
  const { pending } = useFormStatus();
  return <Button type="submit" disabled={disabled || pending}>{pending ? "Saving..." : children}</Button>;
}

function ActionFeedback({ message, ok }: { message: string; ok: boolean }) {
  if (!message) return null;
  return <p className={`text-sm ${ok ? "text-[#18794e]" : "text-[#a51d3d]"}`}>{message}</p>;
}

export function CandidateVerificationActions({ candidateId, canVerify, blockers }: { candidateId: string; canVerify: boolean; blockers: string[] }) {
  const [verifyState, verifyAction] = useActionState(verifyCandidate, initialAdminActionState);
  const [rejectState, rejectAction] = useActionState(rejectCandidateVerification, initialAdminActionState);
  const [reverifyState, reverifyAction] = useActionState(requireCandidateReverification, initialAdminActionState);

  return (
    <div className="grid gap-4 border-t border-[#f0e4eb] pt-4">
      {!canVerify ? <div className="rounded-lg bg-[#fff8e8] p-3 text-sm text-[#725400]"><p className="font-semibold">Candidate cannot be verified yet</p><ul className="mt-1 list-disc pl-5">{blockers.map((blocker) => <li key={blocker}>{blocker}</li>)}</ul></div> : null}
      <form action={verifyAction} className="grid gap-2 sm:grid-cols-[1fr_auto]">
        <input type="hidden" name="candidateId" value={candidateId} />
        <input name="internalNotes" maxLength={500} placeholder="Internal admin notes (not shown to the candidate)" className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 text-sm" />
        <SubmitButton disabled={!canVerify}>Verify Candidate</SubmitButton>
        <ActionFeedback {...verifyState} />
      </form>
      <div className="grid gap-3 md:grid-cols-2">
        <form action={rejectAction} className="grid gap-2">
          <input type="hidden" name="candidateId" value={candidateId} />
          <textarea name="candidateMessage" required minLength={6} maxLength={500} placeholder="Reason shown to candidate" className="focus-ring min-h-24 rounded-lg border border-[#ded2da] p-3 text-sm" />
          <textarea name="internalNotes" maxLength={500} placeholder="Internal admin notes (not shown to candidate)" className="focus-ring min-h-20 rounded-lg border border-[#ded2da] p-3 text-sm" />
          <SubmitButton>Reject Verification</SubmitButton>
          <ActionFeedback {...rejectState} />
        </form>
        <form action={reverifyAction} className="grid gap-2">
          <input type="hidden" name="candidateId" value={candidateId} />
          <textarea name="candidateMessage" required minLength={6} maxLength={500} placeholder="Reason shown to candidate" className="focus-ring min-h-24 rounded-lg border border-[#ded2da] p-3 text-sm" />
          <textarea name="internalNotes" maxLength={500} placeholder="Internal admin notes (not shown to candidate)" className="focus-ring min-h-20 rounded-lg border border-[#ded2da] p-3 text-sm" />
          <SubmitButton>Require Reverification</SubmitButton>
          <ActionFeedback {...reverifyState} />
        </form>
      </div>
    </div>
  );
}
