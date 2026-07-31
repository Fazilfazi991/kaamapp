import { notFound } from "next/navigation";
import { AdminPageHeader, AdminStatus, DetailSection, Field, SafeLink } from "@/features/admin/components/admin-ui";
import { candidateOperationalStatusLabel } from "@/features/admin/server/candidate-accounts";
import { loadCandidate } from "@/features/admin/server/data";

type CandidateNotification = {
  id: string;
  title: string;
  body: string;
  created_at: string | null;
};

export default async function AdminCandidateDetailPage({
  params,
}: {
  params: Promise<{ candidateId: string }>;
}) {
  const { candidateId } = await params;
  const { candidate, membership, versions, notifications } = await loadCandidate(candidateId);
  if (!candidate) notFound();
  const docs = candidate.candidate_documents?.[0];

  return (
    <>
      <AdminPageHeader title={candidate.profiles?.full_name ?? "Candidate"} description="Candidate profile, verification summary, review history, and safe account context." />
      <DetailSection title="Profile summary">
        <div className="grid gap-4 md:grid-cols-3">
          <Field label="Email" value={candidate.profiles?.email} />
          <Field label="Location" value={[candidate.current_city, candidate.current_country].filter(Boolean).join(", ")} />
          <Field label="Account status" value={<AdminStatus status={candidate.profiles?.status} />} />
          <Field label="Candidate status" value={candidateOperationalStatusLabel(candidate.operational_status)} />
          <Field label="Profile completion" value={`${candidate.profile_completion}%`} />
          <Field label="Headline" value={candidate.headline} />
          <Field label="Experience" value={candidate.experience_years} />
          <Field label="Availability" value={candidate.availability} />
          <Field label="Skills" value={candidate.skills?.join(", ")} />
          <Field label="Languages" value={candidate.languages?.join(", ")} />
          <Field label="Membership" value={membership?.status ?? "No membership"} />
        </div>
        {!candidate.has_candidate_profile ? (
          <p className="rounded-lg border border-dashed border-[#d8c8d1] bg-[#fffafc] p-4 text-sm text-[#66616f]">
            This candidate has not completed their profile yet.
          </p>
        ) : candidate.missing_sections.length ? (
          <p className="text-sm text-[#66616f]">Missing sections: {candidate.missing_sections.join(", ")}</p>
        ) : null}
      </DetailSection>
      <DetailSection title="Verification summary">
        <div className="grid gap-4 md:grid-cols-2">
          <Field label="Passport status" value={<AdminStatus status={docs?.passport_status} />} />
          <Field label="Visa status" value={<AdminStatus status={docs?.visa_status} />} />
          <Field label="Passport expiry" value={docs?.passport_expiry_date} />
          <Field label="Visa expiry" value={docs?.visa_expiry_date} />
        </div>
      </DetailSection>
      <DetailSection title="Submitted documents">
        {versions.length ? versions.map((version) => (
          <div key={`${version.source}:${version.id}:${version.document_type}`} className="flex flex-col gap-2 rounded-lg border border-[#eadde3] p-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p className="font-semibold text-[#201925]">
                {version.document_type} v{version.version_number}
                {version.is_historical ? <span className="ml-2 text-xs text-[#8a7c88]">Historical</span> : null}
              </p>
              <div className="mt-2 flex flex-wrap items-center gap-2">
                <AdminStatus status={version.status} />
                <span className="text-xs text-[#66616f]">Submitted {version.created_at?.slice(0, 10) ?? "Unknown"}</span>
              </div>
            </div>
            <SafeLink href={`/admin/candidate-documents/${version.id}`}>View/Review</SafeLink>
          </div>
        )) : <p>No submitted document versions.</p>}
      </DetailSection>
      <DetailSection title="Review history">
        {notifications.length ? (notifications as CandidateNotification[]).map((item) => (
          <p key={item.id}>{item.created_at?.slice(0, 10)} - {item.title}: {item.body}</p>
        )) : <p>No candidate document notifications recorded.</p>}
      </DetailSection>
    </>
  );
}
