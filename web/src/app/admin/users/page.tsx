import { blockUser, unblockUser } from "@/features/admin/server/actions";
import { AdminPageHeader, AdminStatus, AdminTable, FilterBar, RowAction } from "@/features/admin/components/admin-ui";
import { loadUsers } from "@/features/admin/server/data";
import { Button } from "@/components/ui/button";

export default async function AdminUsersPage({ searchParams }: { searchParams: Promise<{ q?: string; status?: string; page?: string }> }) {
  const params = await searchParams;
  const { rows } = await loadUsers({ q: params.q, status: params.status, page: Number(params.page ?? 1) });
  return (
    <>
      <AdminPageHeader title="Users" description="Account status management through the existing profiles.status field. Role changes and deletion are intentionally excluded." />
      <FilterBar search={params.q} status={params.status} />
      <AdminTable
        headers={["User", "Role", "Status", "Registered", "Actions"]}
        empty="No users match these filters."
        rows={rows.map((user) => (
          <tr key={user.id} className="block rounded-lg border border-[#eadde3] p-4 md:table-row md:border-0 md:p-0">
            <td className="px-4 py-3 font-semibold text-[#201925]">{user.full_name ?? user.email ?? user.id}</td>
            <td className="px-4 py-3 text-[#66616f]">{user.role}</td>
            <td className="px-4 py-3"><AdminStatus status={user.status} /></td>
            <td className="px-4 py-3 text-[#66616f]">{user.created_at?.slice(0, 10) ?? "Unknown"}</td>
            <td className="px-4 py-3">
              <div className="flex flex-wrap gap-2">
                <RowAction href={`/admin/users/${user.id}`}>View</RowAction>
                <form action={user.status === "blocked" ? unblockUser : blockUser}>
                  <input type="hidden" name="userId" value={user.id} />
                  <Button type="submit" variant="secondary" className="min-h-9 px-3 py-2">{user.status === "blocked" ? "Unblock" : "Block"}</Button>
                </form>
              </div>
            </td>
          </tr>
        ))}
      />
    </>
  );
}
