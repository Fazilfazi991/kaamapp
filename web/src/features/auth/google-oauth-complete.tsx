"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { routes } from "@/config/routes";
import { dashboardForRole, isBlockedStatus, safeReturnPath, type AppAccountRole } from "@/lib/auth/routing";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { UserRole } from "@/types/domain";

type State = "checking" | "choose-role" | "error";

const oauthErrors: Record<string, string> = {
  cancelled: "Google sign-in was cancelled. You can try again whenever you are ready.",
  expired: "That Google sign-in link has expired or was already used. Please try again.",
  failed: "Google sign-in could not be completed. Please try again.",
};

export function GoogleOAuthComplete() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const supabase = useMemo(() => createBrowserSupabaseClient(), []);
  const [state, setState] = useState<State>("checking");
  const initialError = searchParams.get("oauthError") ? oauthErrors[searchParams.get("oauthError") ?? ""] ?? oauthErrors.failed : "";
  const [error, setError] = useState(initialError);
  const [loadingRole, setLoadingRole] = useState<AppAccountRole | null>(null);

  const destinationFor = useCallback((role: UserRole) => {
    const requested = safeReturnPath(searchParams.get("next"));
    return requested?.startsWith(`/${role}`) ? requested : dashboardForRole(role);
  }, [searchParams]);

  useEffect(() => {
    if (initialError) return;

    let active = true;
    async function resolveAccount() {
      const { data: { user }, error: userError } = await supabase.auth.getUser();
      if (!active) return;
      if (userError || !user) {
        setError("We could not confirm your Google session. Please try again.");
        setState("error");
        return;
      }

      const { data: profile, error: profileError } = await supabase
        .from("profiles")
        .select("role,status")
        .eq("id", user.id)
        .maybeSingle<{ role: UserRole; status: string | null }>();
      if (!active) return;
      if (profileError) {
        setError("We could not load your KAAM account. Please try again.");
        setState("error");
        return;
      }
      if (!profile?.role) {
        setState("choose-role");
        return;
      }
      if (isBlockedStatus(profile.status)) {
        router.replace(routes.accountBlocked);
      } else {
        router.replace(destinationFor(profile.role));
      }
      router.refresh();
    }
    void resolveAccount();
    return () => { active = false; };
  }, [destinationFor, initialError, router, supabase]);

  async function chooseRole(role: AppAccountRole) {
    if (loadingRole) return;
    setLoadingRole(role);
    setError("");
    const { data, error: bootstrapError } = await supabase
      .rpc("bootstrap_user_profile", { selected_role: role })
      .maybeSingle<{ role: UserRole; status: string | null }>();
    if (bootstrapError || !data?.role) {
      setLoadingRole(null);
      setError("We could not finish setting up your KAAM profile. Please try again.");
      return;
    }
    if (isBlockedStatus(data.status)) {
      router.replace(routes.accountBlocked);
    } else {
      router.replace(destinationFor(data.role));
    }
    router.refresh();
  }

  if (state === "checking") return <p className="text-sm text-[#66616f]">Completing Google sign-in…</p>;

  if (error && state !== "choose-role") {
    return <div className="rounded-lg border border-[#f3c3d3] bg-[#fff7fa] p-5"><p className="text-sm text-[#9a1744]">{error}</p><Button className="mt-4 w-full" onClick={() => router.replace(routes.login)}>Back to login</Button></div>;
  }

  return <div className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm"><h2 className="text-xl font-bold text-[#201925]">How will you use KAAM?</h2><p className="mt-2 text-sm leading-6 text-[#66616f]">Choose once to set up your account. This cannot be changed later.</p>{error ? <p className="mt-4 rounded-lg bg-[#ffe4eb] px-3 py-2 text-sm text-[#9a1744]">{error}</p> : null}<div className="mt-5 grid gap-3 sm:grid-cols-2"><Button type="button" onClick={() => chooseRole("candidate")} disabled={Boolean(loadingRole)}>{loadingRole === "candidate" ? "Setting up…" : "I’m looking for work"}</Button><Button type="button" variant="secondary" onClick={() => chooseRole("employer")} disabled={Boolean(loadingRole)}>{loadingRole === "employer" ? "Setting up…" : "I’m hiring"}</Button></div></div>;
}
