import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireRole } from "@/lib/auth/session";
import { routes } from "@/config/routes";
import type { EmployerCompany } from "@/features/employer/types";

export type EmployerAccess =
  | { ok: true; userId: string; company: EmployerCompany; warning: string | null }
  | { ok: false; userId: string; reason: "missing_company" | "blocked" | "rejected"; message: string };

export async function resolveEmployerAccess({ redirectIncomplete = false } = {}): Promise<EmployerAccess> {
  const account = await requireRole("employer");
  const supabase = await createServerSupabaseClient();
  const { data: company } = await supabase
    .from("employer_companies")
    .select("*")
    .eq("owner_id", account.userId)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle<EmployerCompany>();

  if (!company) {
    if (redirectIncomplete) redirect(routes.employerOnboarding);
    return {
      ok: false,
      userId: account.userId,
      reason: "missing_company",
      message: "Create and save your company profile before searching candidates.",
    };
  }
  if (company.status === "blocked") {
    return {
      ok: false,
      userId: account.userId,
      reason: "blocked",
      message: "This company profile cannot currently contact candidates. Review your company profile before continuing.",
    };
  }
  if (company.status === "rejected") {
    return {
      ok: false,
      userId: account.userId,
      reason: "rejected",
      message: "This company profile needs correction before candidate actions are available.",
    };
  }

  const required = [company.company_name, company.city, company.contact_person];
  const warning = required.some((value) => !value?.trim())
    ? "Complete your company profile to improve candidate trust."
    : company.is_verified
      ? null
      : "Company review is pending. Candidate contact details still follow match and reveal rules.";

  return { ok: true, userId: account.userId, company, warning };
}

export async function requireEmployerCompany() {
  const access = await resolveEmployerAccess({ redirectIncomplete: true });
  if (!access.ok) throw new Error(access.message);
  return access;
}
