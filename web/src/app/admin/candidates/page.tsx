import { AdminErrorState, AdminPageHeader, AdminStatus, AdminTable, FilterBar, ManualVerificationStatus, RowAction } from "@/features/admin/components/admin-ui";
import { extractCandidateDocumentSummary, loadCandidates } from "@/features/admin/server/data";

const candidateStatusOptions = [
  { value: "not_submitted", label: "Not submitted" },
  { value: "pending_verification", label: "Awaiting verification" },
  { value: "verified", label: "Verified" },
  { value: "rejected", label: "Rejected" },
  { value: "reverification_required", label: "Reverification required" },
  { value: "blocked", label: "Blocked" },
];

export default async function AdminCandidatesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string; page?: string }>;
}) {
  const params = await searchParams;
  const { rows, errorMessage } = await loadCandidates({ q: params.q, status: params.status, page: Number(params.page ?? 1) });

  return (
    <>
      <AdminPageHeader title="Candidates" description="Account, profile, manual verification, and document statuses are shown independently." />
      <FilterBar search={params.q} status={params.status} statusOptions={candidateStatusOptions} />
      {errorMessage ? <AdminErrorState message={errorMessage} /> : (
        <AdminTable
          headers={["Candidate", "Location", "Account", "Profile completion", "Verification status", "Documents", "Updated", "Action"]}
          empty={params.q || params.status ? "No candidates match these filters." : "No candidate accounts have been created yet."}
          rows={rows.map((candidate) => {
            const docs = extractCandidateDocumentSummary(candidate.candidate_documents);
            return (
              <tr key={candidate.id} className="block rounded-lg border border-[#eadde3] p-4 md:table-row md:border-0 md:p-0">
                <td className="px-4 py-3 font-semibold text-[#201925]">{candidate.profiles?.full_name ?? candidate.headline ?? "Candidate"}</td>
                <td className="px-4 py-3 text-[#66616f]">{[candidate.current_city, candidate.current_country].filter(Boolean).join(", ") || "Not provided"}</td>
                <td className="px-4 py-3"><AdminStatus status={candidate.profiles?.status} /></td>
                <td className="px-4 py-3 text-[#66616f]">{candidate.profile_completion}% complete</td>
                <td className="px-4 py-3"><ManualVerificationStatus status={candidate.verification_status} /></td>
                <td className="px-4 py-3 text-[#66616f]"><div className="grid gap-1"><span>Passport: <AdminStatus status={docs?.passport_status ?? "not_uploaded"} /></span><span>Visa: <AdminStatus status={docs?.visa_status ?? "not_uploaded"} /></span></div></td>
                <td className="px-4 py-3 text-[#66616f]">{candidate.updated_at?.slice(0, 10) ?? "Unknown"}</td>
                <td className="px-4 py-3"><RowAction href={`/admin/candidates/${candidate.id}`}>Review</RowAction></td>
              </tr>
            );
          })}
        />
      )}
    </>
  );
}
