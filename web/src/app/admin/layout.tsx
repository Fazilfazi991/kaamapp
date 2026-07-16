import { AdminShell } from "@/features/admin/components/admin-shell";
import { requireAdmin } from "@/features/admin/auth/require-admin";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const account = await requireAdmin();
  return <AdminShell account={account}>{children}</AdminShell>;
}
