import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { routes } from "@/config/routes";
import type { AdminAccount, AdminProfileRow } from "@/features/admin/types";

export async function requireAdmin(): Promise<AdminAccount> {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect(routes.candidateLogin);

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, role, full_name, email, status")
    .eq("id", user.id)
    .maybeSingle<AdminProfileRow>();

  if (profile?.status === "blocked") redirect(routes.accountBlocked);

  if (!profile || profile.role !== "admin") {
    if (profile?.role === "candidate") redirect(routes.candidateDashboard);
    if (profile?.role === "employer") redirect(routes.employerDashboard);
    redirect(routes.accountSetup);
  }

  return {
    userId: user.id,
    email: user.email ?? profile.email,
    role: "admin",
    profileStatus: profile.status,
  };
}
