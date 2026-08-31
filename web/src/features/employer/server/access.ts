import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireRole } from "@/lib/auth/session";
import type { EmployerCompany } from "@/features/employer/types";
import { validateEmployerLocation } from "@/features/employer/profile/validation";

export type EmployerAccess =
  | { ok: true; userId: string; company: EmployerCompany; warning: string | null }
  | { ok: false; userId: string; reason: "missing_company" | "blocked" | "rejected"; message: string };

export async function resolveEmployerAccess(): Promise<EmployerAccess> {
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

  const required = [company.company_name, company.contact_person];
  const locationValid = validateEmployerLocation(company.country ?? "", company.city ?? "", company.office_area ?? "").ok;
  const warning = required.some((value) => !value?.trim()) || !locationValid
    ? "Complete your company profile to improve candidate trust."
    : company.is_verified
      ? null
      : "Optional business verification has not been completed. This does not affect your employer account or workspace access.";

  return { ok: true, userId: account.userId, company, warning };
}

export async function requireEmployerCompany() {
  const access = await resolveEmployerAccess();
  if (!access.ok) throw new Error(access.message);
  return access;
}
