import { AdminErrorState, AdminPageHeader, AdminStatus, AdminTable, FilterBar, RowAction } from "@/features/admin/components/admin-ui";
import { candidateOperationalStatusLabel } from "@/features/admin/server/candidate-accounts";
import { extractCandidateDocumentSummary, loadCandidates } from "@/features/admin/server/data";

const candidateStatusOptions = [
  { value: "profile_missing", label: "Profile missing" },
  { value: "draft", label: "Draft" },
  { value: "incomplete", label: "Incomplete" },
  { value: "pending_verification", label: "Pending verification" },
  { value: "verified", label: "Verified" },
  { value: "rejected", label: "Rejected" },
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
      <AdminPageHeader title="Candidates" description="Candidate operational management for every candidate-role account, including missing or incomplete onboarding profiles." />
      <FilterBar search={params.q} status={params.status} statusOptions={candidateStatusOptions} />
      {errorMessage ? (
        <AdminErrorState message={errorMessage} />
      ) : (
        <AdminTable
          headers={["Candidate", "Location", "Account", "Profile", "Documents", "Updated", "Action"]}
          empty={params.q || params.status ? "No candidates match these filters." : "No candidate accounts have been created yet."}
          rows={rows.map((candidate) => {
            const docs = extractCandidateDocumentSummary(candidate.candidate_documents);
            return (
              <tr key={candidate.id} className="block rounded-lg border border-[#eadde3] p-4 md:table-row md:border-0 md:p-0">
                <td className="px-4 py-3 font-semibold text-[#201925]">{candidate.profiles?.full_name ?? candidate.headline ?? "Candidate"}</td>
                <td className="px-4 py-3 text-[#66616f]">{[candidate.current_city, candidate.current_country].filter(Boolean).join(", ") || "Not provided"}</td>
                <td className="px-4 py-3"><AdminStatus status={candidate.profiles?.status} /></td>
                <td className="px-4 py-3 text-[#66616f]">
                  {candidateOperationalStatusLabel(candidate.operational_status)} · {candidate.profile_completion}% complete
                </td>
                <td className="px-4 py-3 text-[#66616f]">Passport {docs?.passport_status ?? "not_uploaded"} / Visa {docs?.visa_status ?? "not_uploaded"}</td>
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
