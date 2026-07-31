import { AdminErrorState, AdminPageHeader, AdminStatus, AdminTable, FilterBar, RowAction } from "@/features/admin/components/admin-ui";
import { loadCandidateDocuments } from "@/features/admin/server/data";
import { candidateDocumentStatusOptions } from "@/features/admin/validation/review";

export default async function AdminCandidateDocumentsPage({ searchParams }: { searchParams: Promise<{ q?: string; status?: string; page?: string }> }) {
  const params = await searchParams;
  const { rows, errorMessage } = await loadCandidateDocuments({ q: params.q, status: params.status, page: Number(params.page ?? 1) });
  const hasFilters = Boolean(params.q?.trim() || params.status?.trim());
  return (
    <>
      <AdminPageHeader title="Candidate documents" description="Active and historical candidate document versions from the existing candidate document tables." />
      <FilterBar search={params.q} status={params.status} statusOptions={candidateDocumentStatusOptions()} />
      {errorMessage ? (
        <AdminErrorState message={errorMessage} />
      ) : (
        <AdminTable
          headers={["Candidate", "Type", "Version", "Status", "Submitted", "Expiry", "Action"]}
          empty={hasFilters ? "No candidate documents match these filters." : "No candidate documents have been submitted yet."}
          rows={rows.map((document) => (
            <tr key={`${document.source}:${document.id}:${document.document_type}`} className="block rounded-lg border border-[#eadde3] p-4 md:table-row md:border-0 md:p-0">
              <td className="px-4 py-3 font-semibold text-[#201925]">{document.candidate_profiles?.profiles?.full_name ?? document.candidate_id}</td>
              <td className="px-4 py-3 text-[#66616f]">{document.document_type}</td>
              <td className="px-4 py-3 text-[#66616f]">
                v{document.version_number}
                {document.is_historical ? <span className="ml-2 text-xs font-semibold text-[#8a7c88]">Historical</span> : null}
                {document.source === "summary" ? <span className="ml-2 text-xs font-semibold text-[#8a7c88]">Summary</span> : null}
              </td>
              <td className="px-4 py-3"><AdminStatus status={document.status} /></td>
              <td className="px-4 py-3 text-[#66616f]">{document.created_at?.slice(0, 10) ?? "Unknown"}</td>
              <td className="px-4 py-3 text-[#66616f]">{document.expiry_date ?? "Not provided"}</td>
              <td className="px-4 py-3"><RowAction href={`/admin/candidate-documents/${document.id}`}>View/Review</RowAction></td>
            </tr>
          ))}
        />
      )}
    </>
  );
}
