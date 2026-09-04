import { cache } from "react";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { demoPublicHiringRequirements } from "@/features/public-jobs/demo-data";
import type { PublicHiringRequirement } from "@/features/public-jobs/types";

export const loadPublicHiringRequirements = cache(async function loadPublicHiringRequirements(limit = 12) {
  const safeLimit = Math.min(Math.max(limit, 1), 15);
  if (process.env.KAAM_PUBLIC_JOBS_DEMO === "true") {
    return demoPublicHiringRequirements.slice(0, safeLimit);
  }

  try {
    const supabase = await createServerSupabaseClient();
    const { data, error } = await supabase
      .rpc("list_public_hiring_requirements", { result_limit: safeLimit });

    if (error) return [];
    return (data ?? []) as PublicHiringRequirement[];
  } catch {
    return [];
  }
});
