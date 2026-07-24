import { Suspense } from "react";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { RouteLoading } from "@/components/layout/route-loading";
import { candidateNavigation } from "@/config/navigation";
import { requireRole } from "@/lib/auth/session";

export default function CandidateLayout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense
      fallback={
        <DashboardShell
          account={{ email: null, role: "candidate" }}
          items={candidateNavigation}
          title="Candidate"
        >
          <RouteLoading label="Opening candidate workspace…" />
        </DashboardShell>
      }
    >
      <CandidateProtectedShell>{children}</CandidateProtectedShell>
    </Suspense>
  );
}

async function CandidateProtectedShell({ children }: { children: React.ReactNode }) {
  const account = await requireRole("candidate");
  return (
    <DashboardShell
      account={{ email: account.email, role: account.role }}
      items={candidateNavigation}
      title="Candidate"
    >
      {children}
    </DashboardShell>
  );
}
