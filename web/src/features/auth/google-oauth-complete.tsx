"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { routes } from "@/config/routes";
import {
  authenticatedEntryDestination,
  dashboardForRole,
  isBlockedStatus,
  loginForRole,
  modeForJourney,
  parseAuthJourney,
  registerForRole,
  roleForJourney,
  type AppAccountRole,
} from "@/lib/auth/routing";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { UserRole } from "@/types/domain";
import { track } from "@/features/analytics/tracker";

type State = "checking" | "not-registered" | "error";

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
  const [loadingRole, setLoadingRole] = useState(false);
  const journey = parseAuthJourney(searchParams.get("journey"));
  const intendedRole = journey ? roleForJourney(journey) : null;
  const intendedMode = journey ? modeForJourney(journey) : null;

  const destinationFor = useCallback((role: UserRole) => {
    return authenticatedEntryDestination(role, searchParams.get("next"));
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
        if (!intendedRole || intendedMode !== "register") {
          await supabase.auth.signOut({ scope: "local" });
          if (!active) return;
          setError(
            intendedRole
              ? `We couldn't find a ${intendedRole === "candidate" ? "Candidate" : "Employer"} account for this Google account.`
              : "We couldn't determine which KAAM registration journey you started.",
          );
          setState("not-registered");
          return;
        }
        await chooseRegistrationRole(intendedRole);
        return;
      }
      track("login_success", { auth_method: "google", account_type: profile.role });
      if (isBlockedStatus(profile.status)) {
        router.replace(routes.accountBlocked);
      } else {
        const destination = new URL(
          intendedRole && profile.role !== intendedRole
            ? dashboardForRole(profile.role)
            : destinationFor(profile.role),
          window.location.origin,
        );
        if (intendedRole && profile.role !== intendedRole) destination.searchParams.set("authNotice", "role-redirect");
        router.replace(`${destination.pathname}${destination.search}`);
      }
      router.refresh();
    }
    void resolveAccount();
    return () => { active = false; };
    async function chooseRegistrationRole(role: AppAccountRole) {
      setLoadingRole(true);
      const { data, error: bootstrapError } = await supabase
        .rpc("bootstrap_user_profile", { selected_role: role })
        .maybeSingle<{ role: UserRole; status: string | null }>();
      if (!active) return;
      if (bootstrapError || !data?.role) {
        setLoadingRole(false);
        setError("We could not finish setting up your KAAM profile. Please try again.");
        setState("error");
        return;
      }
      track("account_type_selected", { account_type: data.role as "candidate" | "employer" });
      track("registration_completed", { role: data.role, auth_method: "google" });
      router.replace(isBlockedStatus(data.status) ? routes.accountBlocked : destinationFor(data.role));
      router.refresh();
    }
  }, [destinationFor, initialError, intendedMode, intendedRole, router, supabase]);

  if (state === "not-registered") {
    const role = intendedRole ?? "candidate";
    return <div className="rounded-xl border border-[#f3c3d3] bg-[#fff7fa] p-5"><h2 className="text-lg font-bold text-[#201925]">Account not registered</h2><p className="mt-2 text-sm leading-6 text-[#9a1744]">{error}</p><div className="mt-5 grid gap-3"><Button onClick={() => router.replace(registerForRole(role))}>Register as {role === "candidate" ? "a Candidate" : "an Employer"}</Button><Button variant="secondary" onClick={() => router.replace(loginForRole(role))}>Back to {role === "candidate" ? "Candidate" : "Employer"} login</Button></div></div>;
  }

  if (error) {
    const role = intendedRole ?? "candidate";
    return <div className="rounded-xl border border-[#f3c3d3] bg-[#fff7fa] p-5"><p className="text-sm text-[#9a1744]">{error}</p><Button className="mt-4 w-full" onClick={() => router.replace(loginForRole(role))}>Back to login</Button></div>;
  }

  return <p className="text-sm text-[#66616f]">{loadingRole ? "Setting up your account…" : "Completing Google sign-in…"}</p>;
}
