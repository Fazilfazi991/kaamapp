import { AdminPageHeader, AdminStatus, AdminTable, FilterBar, RowAction } from "@/features/admin/components/admin-ui";
import { extractCandidateDocumentSummary, loadCandidates } from "@/features/admin/server/data";

export default async function AdminCandidatesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string; page?: string }>;
}) {
  const params = await searchParams;
  const { rows } = await loadCandidates({ q: params.q, status: params.status, page: Number(params.page ?? 1) });

  return (
    <>
      <AdminPageHeader title="Candidates" description="Review candidate profile and verification state without exposing sensitive identity fields in the queue." />
      <FilterBar search={params.q} status={params.status} />
      <AdminTable
        headers={["Candidate", "Location", "Profile", "Documents", "Updated", "Action"]}
        empty="No candidates match these filters."
        rows={rows.map((candidate) => {
          const docs = extractCandidateDocumentSummary(candidate.candidate_documents);
          return (
            <tr key={candidate.id} className="block rounded-lg border border-[#eadde3] p-4 md:table-row md:border-0 md:p-0">
              <td className="px-4 py-3 font-semibold text-[#201925]">{candidate.profiles?.full_name ?? candidate.headline ?? "Candidate"}</td>
              <td className="px-4 py-3 text-[#66616f]">{[candidate.current_city, candidate.current_country].filter(Boolean).join(", ") || "Not set"}</td>
              <td className="px-4 py-3"><AdminStatus status={candidate.profiles?.status} /></td>
              <td className="px-4 py-3 text-[#66616f]">Passport {docs?.passport_status ?? "not_uploaded"} / Visa {docs?.visa_status ?? "not_uploaded"}</td>
              <td className="px-4 py-3 text-[#66616f]">{candidate.updated_at?.slice(0, 10) ?? "Unknown"}</td>
              <td className="px-4 py-3"><RowAction href={`/admin/candidates/${candidate.id}`}>Review</RowAction></td>
            </tr>
          );
        })}
      />
    </>
  );
}
