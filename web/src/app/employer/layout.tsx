import { Suspense } from "react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { RouteLoading } from "@/components/layout/route-loading";
import { employerNavigation } from "@/config/navigation";
import { requireRole } from "@/lib/auth/session";

export default function EmployerLayout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense
      fallback={
        <DashboardShell
          account={{ email: null, role: "employer" }}
          items={employerNavigation}
          title="Employer"
        >
          <RouteLoading label="Opening employer workspace…" />
        </DashboardShell>
      }
    >
      <EmployerProtectedShell>{children}</EmployerProtectedShell>
    </Suspense>
  );
}

async function EmployerProtectedShell({ children }: { children: React.ReactNode }) {
  const account = await requireRole("employer");
  return (
    <DashboardShell
      account={{ email: account.email, role: account.role }}
      items={employerNavigation}
      title="Employer"
    >
      {children}
    </DashboardShell>
  );
}
