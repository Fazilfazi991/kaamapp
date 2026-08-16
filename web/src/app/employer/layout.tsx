import { Suspense } from "react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { employerNavigation } from "@/config/navigation";
import EmployerLoading from "./loading";
import { EmployerRoleGate } from "./employer-role-gate";

export default function EmployerLayout({ children }: { children: React.ReactNode }) {
  return (
    <DashboardShell
      items={employerNavigation}
      title="Employer"
    >
      <Suspense fallback={<EmployerLoading />}>
        <EmployerRoleGate>{children}</EmployerRoleGate>
      </Suspense>
    </DashboardShell>
  );
}
