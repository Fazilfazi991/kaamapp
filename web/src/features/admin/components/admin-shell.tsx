import { DashboardShell } from "@/components/layout/dashboard-shell";
import type { AdminAccount } from "@/features/admin/types";

export const adminNavItems = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/candidates", label: "Candidates" },
  { href: "/admin/candidate-documents", label: "Candidate docs" },
  { href: "/admin/employers", label: "Employers" },
  { href: "/admin/employer-documents", label: "Employer docs" },
  { href: "/admin/users", label: "Users" },
  { href: "/admin/reports", label: "Reports" },
  { href: "/admin/audit", label: "Audit" },
];

export function AdminShell({ account, children }: { account: AdminAccount; children: React.ReactNode }) {
  return (
    <DashboardShell items={adminNavItems} title="Admin" account={{ email: account.email, role: account.role }}>
      {children}
    </DashboardShell>
  );
}
