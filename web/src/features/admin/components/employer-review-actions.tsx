"use client";

import { useActionState } from "react";
import { Button, ButtonLink } from "@/components/ui/button";
import { approveEmployerCompany, approveEmployerDocument, rejectEmployerDocument } from "@/features/admin/server/actions";
import { initialAdminActionState, type AdminActionState } from "@/features/admin/validation/review";

function ActionMessage({ state }: { state: AdminActionState }) {
  if (!state.message) return null;
  return (
    <p className={`rounded-lg border p-3 text-sm font-medium ${state.ok ? "border-[#b9e3c6] bg-[#f0fff4] text-[#176534]" : "border-[#f1b6c8] bg-[#fff4f7] text-[#8f1741]"}`}>
      {state.message}
    </p>
  );
}

export function EmployerDocumentReviewActions({
  documentId,
  companyId,
  canApprove,
  canRequestResubmission,
}: {
  documentId: string;
  companyId?: string | null;
  canApprove: boolean;
  canRequestResubmission: boolean;
}) {
  const [approveState, approveAction, approving] = useActionState(approveEmployerDocument, initialAdminActionState);
  const [rejectState, rejectAction, rejecting] = useActionState(rejectEmployerDocument, initialAdminActionState);

  if (!canApprove && !canRequestResubmission) {
    return companyId ? <ButtonLink href={`/admin/employers/${companyId}`} variant="secondary">Back to company</ButtonLink> : null;
  }

  return (
    <div className="grid gap-3 md:grid-cols-2">
      {canApprove ? (
        <form action={approveAction} className="grid gap-3">
          <input type="hidden" name="documentId" value={documentId} />
          <Button type="submit" className="w-full" disabled={approving}>
            {approving ? "Approving..." : "Approve document"}
          </Button>
          <ActionMessage state={approveState} />
        </form>
      ) : null}
      {canRequestResubmission ? (
        <form action={rejectAction} className="grid gap-3">
          <input type="hidden" name="documentId" value={documentId} />
          <label className="text-sm font-semibold text-[#201925]" htmlFor="reason">Public rejection reason</label>
          <textarea id="reason" name="reason" required className="focus-ring min-h-24 rounded-lg border border-[#ded2da] p-3 text-sm" />
          <Button type="submit" variant="secondary" disabled={rejecting}>
            {rejecting ? "Saving..." : "Request resubmission"}
          </Button>
          <ActionMessage state={rejectState} />
        </form>
      ) : null}
    </div>
  );
}

export function EmployerCompanyApprovalForm({
  companyId,
  canApprove,
}: {
  companyId: string;
  canApprove: boolean;
}) {
  const [state, action, pending] = useActionState(approveEmployerCompany, initialAdminActionState);

  if (!canApprove) {
    return <ActionMessage state={state} />;
  }

  return (
    <form action={action} className="grid gap-3">
      <input type="hidden" name="companyId" value={companyId} />
      <Button type="submit" disabled={pending}>{pending ? "Approving..." : "Approve company"}</Button>
      <ActionMessage state={state} />
    </form>
  );
}

