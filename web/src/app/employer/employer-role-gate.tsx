import { requireRole } from "@/lib/auth/session";

export async function EmployerRoleGate({ children }: { children: React.ReactNode }) {
  await requireRole("employer");
  return children;
}
