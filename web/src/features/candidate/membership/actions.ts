"use server";

import { revalidatePath } from "next/cache";
import { routes } from "@/config/routes";
import { requireRole } from "@/lib/auth/session";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export async function setEmployerVisibility(isVisible: boolean) {
  await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("set_candidate_employer_visibility", {
    p_is_visible: isVisible,
  });
  if (error || data !== isVisible) {
    throw new Error(error?.message ?? "We could not update your profile visibility.");
  }

  revalidatePath(routes.candidateMembership);
  revalidatePath(routes.candidateDashboard);
  revalidatePath(routes.candidateProfile);
  revalidatePath(routes.employerSearch);
  return isVisible;
}
