"use client";

import { useMemo, useState, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { routes } from "@/config/routes";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";

export function LogoutButton({
  destination = routes.candidateLogin,
  children = "Logout",
  className,
  buttonClassName,
  variant,
}: {
  destination?: string;
  children?: ReactNode;
  className?: string;
  buttonClassName?: string;
  variant?: "primary" | "secondary" | "ghost";
}) {
  const router = useRouter();
  const supabase = useMemo(() => createBrowserSupabaseClient(), []);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function logout() {
    if (loading) return;
    setLoading(true);
    setError("");

    const { error: signOutError } = await supabase.auth.signOut({ scope: "local" });
    if (signOutError) {
      setLoading(false);
      setError("Logout failed. Please try again.");
      return;
    }

    // Do not navigate while this browser client can still resolve the old user.
    const { data } = await supabase.auth.getUser();
    if (data.user) {
      setLoading(false);
      setError("We could not clear your session. Please try again.");
      return;
    }

    router.replace(`${destination}?analytics=logout`);
    router.refresh();
  }

  return (
    <div className={className}>
      <Button type="button" variant={variant} onClick={logout} disabled={loading} className={`w-full ${buttonClassName ?? ""}`}>
        {loading ? "Logging out…" : children}
      </Button>
      {error ? <p role="alert" className="mt-2 text-xs text-[#9a1744]">{error}</p> : null}
    </div>
  );
}
