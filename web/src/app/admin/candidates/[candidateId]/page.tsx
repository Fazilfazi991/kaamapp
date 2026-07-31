import { notFound } from "next/navigation";
import { AdminPageHeader, AdminStatus, DetailSection, Field, ManualVerificationStatus, SafeLink } from "@/features/admin/components/admin-ui";
import { CandidateVerificationActions } from "@/features/admin/components/candidate-verification-actions";
import { loadCandidate } from "@/features/admin/server/data";
import { candidateVerificationEligibility, candidateVerificationLabel } from "@/features/admin/verification-status";

type CandidateNotification = { id: string; title: string; body: string; created_at: string | null };

function formatDate(value?: string | null) {
  return value ? new Intl.DateTimeFormat("en", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value)) : "Not yet verified by an administrator";
}

export default async function AdminCandidateDetailPage({ params }: { params: Promise<{ candidateId: string }> }) {
  const { candidateId } = await params;
  const { candidate, membership, versions, notifications, verificationAudit } = await loadCandidate(candidateId);
  if (!candidate) notFound();

  const docs = candidate.candidate_documents?.[0];
  const eligibility = candidateVerificationEligibility({
    accountStatus: candidate.profiles?.status,
    profileCompletion: candidate.profile_completion,
    passportStatus: docs?.passport_status,
  });
  const currentReview = verificationAudit.find((item) => item.new_status === candidate.verification_status);
  const reviewer = currentReview?.admin?.full_name ?? currentReview?.admin?.email ?? null;

  return (
    <>
      <AdminPageHeader title={candidate.profiles?.full_name ?? "Candidate"} description="Account, profile completion, manual verification, and document statuses are reviewed separately." />
      <DetailSection title="Profile summary">
        <div className="grid gap-4 md:grid-cols-3">
          <Field label="Email" value={candidate.profiles?.email} />
          <Field label="Location" value={[candidate.current_city, candidate.current_country].filter(Boolean).join(", ")} />
          <Field label="Account status" value={<AdminStatus status={candidate.profiles?.status} />} />
          <Field label="Profile completion" value={`${candidate.profile_completion}%`} />
          <Field label="Headline" value={candidate.headline} />
          <Field label="Experience" value={candidate.experience_years} />
          <Field label="Availability" value={candidate.availability} />
          <Field label="Skills" value={candidate.skills?.join(", ")} />
          <Field label="Languages" value={candidate.languages?.join(", ")} />
          <Field label="Membership" value={membership?.status ?? "No membership"} />
        </div>
        {!candidate.has_candidate_profile ? <p className="rounded-lg border border-dashed border-[#d8c8d1] bg-[#fffafc] p-4 text-sm text-[#66616f]">This candidate has not completed their profile yet.</p> : candidate.missing_sections.length ? <p className="text-sm text-[#66616f]">Missing sections: {candidate.missing_sections.join(", ")}</p> : null}
      </DetailSection>
      <DetailSection title="Manual Verification">
        <div className="rounded-lg border border-[#eadde3] bg-[#fffafc] p-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div><p className="font-semibold text-[#201925]">{candidateVerificationLabel(candidate.verification_status)}</p><p className="mt-1 text-sm text-[#66616f]">{candidate.verification_status === "verified" ? "This candidate has been manually verified by an administrator." : "This candidate has not yet been manually verified by an administrator."}</p></div>
            <ManualVerificationStatus status={candidate.verification_status} />
          </div>
          <div className="mt-4 grid gap-4 md:grid-cols-3">
            <Field label={candidate.verification_status === "verified" ? "Verified by" : "Reviewed by"} value={reviewer ?? "Not yet verified by an administrator"} />
            <Field label={candidate.verification_status === "verified" ? "Verified on" : "Last verification action"} value={formatDate(candidate.verification_updated_at)} />
            <Field label={candidate.verification_status === "rejected" ? "Rejection reason" : "Verification notes"} value={candidate.verification_notes ?? "No notes recorded"} />
          </div>
        </div>
        <CandidateVerificationActions candidateId={candidate.id} canVerify={eligibility.canVerify} blockers={eligibility.blockers} />
      </DetailSection>
      <DetailSection title="Document statuses">
        <div className="grid gap-4 md:grid-cols-2">
          <Field label="Passport status" value={<AdminStatus status={docs?.passport_status} />} />
          <Field label="Visa status" value={<AdminStatus status={docs?.visa_status} />} />
          <Field label="Passport expiry" value={docs?.passport_expiry_date} />
          <Field label="Visa expiry" value={docs?.visa_expiry_date} />
        </div>
      </DetailSection>
      <DetailSection title="Submitted documents">
        {versions.length ? versions.map((version) => <div key={`${version.source}:${version.id}:${version.document_type}`} className="flex flex-col gap-2 rounded-lg border border-[#eadde3] p-4 sm:flex-row sm:items-center sm:justify-between"><div><p className="font-semibold text-[#201925]">{version.document_type} v{version.version_number}{version.is_historical ? <span className="ml-2 text-xs text-[#8a7c88]">Historical</span> : null}</p><div className="mt-2 flex flex-wrap items-center gap-2"><AdminStatus status={version.status} /><span className="text-xs text-[#66616f]">Submitted {version.created_at?.slice(0, 10) ?? "Unknown"}</span></div></div><SafeLink href={`/admin/candidate-documents/${version.id}`}>View/Review</SafeLink></div>) : <p>No submitted document versions.</p>}
      </DetailSection>
      <DetailSection title="Document review history">
        {notifications.length ? (notifications as CandidateNotification[]).map((item) => <p key={item.id}>{item.created_at?.slice(0, 10)} - {item.title}: {item.body}</p>) : <p>No candidate document notifications recorded.</p>}
      </DetailSection>
      <DetailSection title="Manual verification audit history">
        {verificationAudit.length ? verificationAudit.map((item) => <p key={item.id}>{formatDate(item.created_at)} - {item.action === "candidate_verified" ? "Candidate manually verified" : item.action === "candidate_verification_rejected" ? "Candidate verification rejected" : "Candidate marked for reverification"}{item.admin?.full_name ? ` by ${item.admin.full_name}` : ""}{item.notes ? `: ${item.notes}` : ""}</p>) : <p>No manual verification actions recorded.</p>}
      </DetailSection>
    </>
  );
}
