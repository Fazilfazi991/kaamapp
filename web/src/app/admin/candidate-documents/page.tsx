import { AdminPageHeader, AdminStatus, AdminTable, FilterBar, RowAction } from "@/features/admin/components/admin-ui";
import { loadCandidateDocuments } from "@/features/admin/server/data";

export default async function AdminCandidateDocumentsPage({ searchParams }: { searchParams: Promise<{ q?: string; status?: string; page?: string }> }) {
  const params = await searchParams;
  const { rows } = await loadCandidateDocuments({ q: params.q, status: params.status, page: Number(params.page ?? 1) });
  return (
    <>
      <AdminPageHeader title="Candidate documents" description="Active and historical candidate document versions from the existing candidate document tables." />
      <FilterBar search={params.q} status={params.status} />
      <AdminTable
        headers={["Candidate", "Type", "Version", "Status", "Submitted", "Action"]}
        empty="No candidate documents match these filters."
        rows={rows.map((document) => (
          <tr key={document.id} className="block rounded-lg border border-[#eadde3] p-4 md:table-row md:border-0 md:p-0">
            <td className="px-4 py-3 font-semibold text-[#201925]">{document.candidate_profiles?.profiles?.full_name ?? document.candidate_id}</td>
            <td className="px-4 py-3 text-[#66616f]">{document.document_type}</td>
            <td className="px-4 py-3 text-[#66616f]">{document.version_number}</td>
            <td className="px-4 py-3"><AdminStatus status={document.status} /></td>
            <td className="px-4 py-3 text-[#66616f]">{document.created_at?.slice(0, 10) ?? "Unknown"}</td>
            <td className="px-4 py-3"><RowAction href={`/admin/candidate-documents/${document.id}`}>Review</RowAction></td>
          </tr>
        ))}
      />
    </>
  );
}
