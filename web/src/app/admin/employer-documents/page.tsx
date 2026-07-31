import { AdminPageHeader, AdminStatus, AdminTable, FilterBar, RowAction } from "@/features/admin/components/admin-ui";
import { loadEmployerDocuments } from "@/features/admin/server/data";

export default async function AdminEmployerDocumentsPage({ searchParams }: { searchParams: Promise<{ q?: string; status?: string; page?: string }> }) {
  const params = await searchParams;
  const { rows } = await loadEmployerDocuments({ q: params.q, status: params.status, page: Number(params.page ?? 1) });
  return (
    <>
      <AdminPageHeader title="Employer documents" description="Review trade-license, authorization-letter, and any additional existing verification document types." />
      <FilterBar search={params.q} status={params.status} />
      <AdminTable
        headers={["Company", "Type", "Status", "Submitted", "Action"]}
        empty="No employer documents match these filters."
        rows={rows.map((document) => (
          <tr key={document.id} className="block rounded-lg border border-[#eadde3] p-4 md:table-row md:border-0 md:p-0">
            <td className="px-4 py-3 font-semibold text-[#201925]">{document.employer_companies?.company_name ?? document.company_id ?? "Company unavailable"}</td>
            <td className="px-4 py-3 text-[#66616f]">{document.document_type}</td>
            <td className="px-4 py-3"><AdminStatus status={document.status} /></td>
            <td className="px-4 py-3 text-[#66616f]">{document.created_at?.slice(0, 10) ?? "Unknown"}</td>
            <td className="px-4 py-3"><RowAction href={`/admin/employer-documents/${document.id}`}>Review</RowAction></td>
          </tr>
        ))}
      />
    </>
  );
}
