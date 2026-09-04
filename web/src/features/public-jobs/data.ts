import { cache } from "react";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { demoPublicHiringRequirements } from "@/features/public-jobs/demo-data";
import type { PublicHiringRequirement } from "@/features/public-jobs/types";

function logPublicJobsLoad({
  source,
  count,
  status,
}: {
  source: "demo" | "live";
  count: number;
  status: "ok" | "rpc_error" | "unexpected_error";
}) {
  const details = {
    source,
    count,
    status,
    environment: process.env.VERCEL_ENV ?? process.env.NODE_ENV ?? "unknown",
  };
  if (status === "ok") console.info("[PublicJobs] load", details);
  else console.warn("[PublicJobs] load", details);
}

export const loadPublicHiringRequirements = cache(async function loadPublicHiringRequirements(limit = 12) {
  const safeLimit = Math.min(Math.max(limit, 1), 15);
  if (process.env.KAAM_PUBLIC_JOBS_DEMO?.trim() === "true") {
    const jobs = demoPublicHiringRequirements.slice(0, safeLimit);
    logPublicJobsLoad({ source: "demo", count: jobs.length, status: "ok" });
    return jobs;
  }

  try {
    const supabase = await createServerSupabaseClient();
    const { data, error } = await supabase
      .rpc("list_public_hiring_requirements", { result_limit: safeLimit });

    if (error) {
      logPublicJobsLoad({ source: "live", count: 0, status: "rpc_error" });
      return [];
    }
    const jobs = (data ?? []) as PublicHiringRequirement[];
    logPublicJobsLoad({ source: "live", count: jobs.length, status: "ok" });
    return jobs;
  } catch {
    logPublicJobsLoad({ source: "live", count: 0, status: "unexpected_error" });
    return [];
  }
});
