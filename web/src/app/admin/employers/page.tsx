import { AdminPageHeader, AdminStatus, AdminTable, FilterBar, RowAction } from "@/features/admin/components/admin-ui";
import { loadEmployers } from "@/features/admin/server/data";

export default async function AdminEmployersPage({ searchParams }: { searchParams: Promise<{ q?: string; status?: string; page?: string }> }) {
  const params = await searchParams;
  const { rows } = await loadEmployers({ q: params.q, status: params.status, page: Number(params.page ?? 1) });
  return (
    <>
      <AdminPageHeader title="Employers" description="Company verification queue using employer_companies and verification_documents." />
      <FilterBar search={params.q} status={params.status} />
      <AdminTable
        headers={["Company", "Owner", "Location", "Company status", "Documents", "Action"]}
        empty="No employers match these filters."
        rows={rows.map((company) => (
          <tr key={company.id} className="block rounded-lg border border-[#eadde3] p-4 md:table-row md:border-0 md:p-0">
            <td className="px-4 py-3 font-semibold text-[#201925]">{company.company_name}</td>
            <td className="px-4 py-3 text-[#66616f]">{company.profiles?.email ?? "Owner email unavailable"}</td>
            <td className="px-4 py-3 text-[#66616f]">{[company.city, company.country].filter(Boolean).join(", ") || "Not set"}</td>
            <td className="px-4 py-3"><AdminStatus status={company.status} /></td>
            <td className="px-4 py-3 text-[#66616f]">{company.verification_documents?.length ?? 0} submitted</td>
            <td className="px-4 py-3"><RowAction href={`/admin/employers/${company.id}`}>Review</RowAction></td>
          </tr>
        ))}
      />
    </>
  );
}
