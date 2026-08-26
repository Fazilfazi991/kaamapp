"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { routes } from "@/config/routes";
import { dashboardForRole, isBlockedStatus, type AppAccountRole } from "@/lib/auth/routing";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { UserRole } from "@/types/domain";

export function AccountSetup({ email }: { email: string | null }) {
  const router = useRouter();
  const supabase = useMemo(() => createBrowserSupabaseClient(), []);
  const [loadingRole, setLoadingRole] = useState<AppAccountRole | null>(null);
  const [error, setError] = useState("");

  async function chooseRole(role: AppAccountRole) {
    if (loadingRole) return;
    setLoadingRole(role);
    setError("");

    const { data, error: bootstrapError } = await supabase
      .rpc("bootstrap_user_profile", { selected_role: role })
      .maybeSingle<{ role: UserRole; status: string | null }>();

    if (bootstrapError || !data?.role) {
      setLoadingRole(null);
      setError("We could not finish setting up your KAAM account. Please try again.");
      return;
    }

    router.replace(isBlockedStatus(data.status) ? routes.accountBlocked : dashboardForRole(data.role));
    router.refresh();
  }

  return (
    <section className="w-full rounded-2xl border border-[#eadde3] bg-white p-6 shadow-[0_18px_42px_rgba(74,35,54,.10)] sm:p-8">
      <p className="text-sm font-semibold text-[#bc1f55]">Account setup</p>
      <h1 className="mt-2 text-2xl font-bold tracking-tight text-[#201925]">How will you use KAAM?</h1>
      <p className="mt-3 text-sm leading-6 text-[#66616f]">You are signed in{email ? ` as ${email}` : ""}. Choose once to create the role for this account. You will not need to sign in again.</p>
      {error ? <p className="mt-4 rounded-lg bg-[#ffe4eb] px-3 py-2 text-sm text-[#9a1744]">{error}</p> : null}
      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        <Button type="button" onClick={() => chooseRole("candidate")} disabled={Boolean(loadingRole)}>
          {loadingRole === "candidate" ? "Setting up…" : "I’m looking for work"}
        </Button>
        <Button type="button" variant="secondary" onClick={() => chooseRole("employer")} disabled={Boolean(loadingRole)}>
          {loadingRole === "employer" ? "Setting up…" : "I’m hiring"}
        </Button>
      </div>
    </section>
  );
}
