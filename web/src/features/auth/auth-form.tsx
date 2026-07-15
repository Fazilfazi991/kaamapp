"use client";

import { useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Label, TextInput } from "@/components/ui/form";
import { routes } from "@/config/routes";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import type { UserRole } from "@/types/domain";

type Step = "email" | "otp";

export function AuthForm({
  initialRole = "candidate",
}: {
  initialRole?: Exclude<UserRole, "admin">;
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const supabase = useMemo(() => createBrowserSupabaseClient(), []);
  const [role, setRole] = useState<Exclude<UserRole, "admin">>(initialRole);
  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function sendOtp() {
    setLoading(true);
    setError("");
    setMessage("");
    const trimmedEmail = email.trim();

    const { error: otpError } = await supabase.auth.signInWithOtp({
      email: trimmedEmail,
      options: {
        shouldCreateUser: true,
        data: { role },
      },
    });

    setLoading(false);
    if (otpError) {
      setError(otpError.message);
      return;
    }

    setStep("otp");
    setMessage("Enter the email OTP sent by Supabase.");
  }

  async function verifyOtp() {
    setLoading(true);
    setError("");
    setMessage("");

    const { data, error: verifyError } = await supabase.auth.verifyOtp({
      email: email.trim(),
      token: otp.trim(),
      type: "email",
    });

    if (verifyError || !data.user) {
      setLoading(false);
      setError(verifyError?.message ?? "OTP verified but no session was created.");
      return;
    }

    const { data: existingProfile, error: roleError } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", data.user.id)
      .maybeSingle<{ role: UserRole }>();

    if (roleError) {
      setLoading(false);
      setError(roleError.message);
      return;
    }

    const storedRole = existingProfile?.role ?? role;
    if (!existingProfile) {
      const { error: upsertError } = await supabase.from("profiles").upsert(
        {
          id: data.user.id,
          role,
          email: data.user.email,
          status: "active",
        },
        { onConflict: "id" },
      );

      if (upsertError) {
        setLoading(false);
        setError(upsertError.message);
        return;
      }
    }

    const destination =
      storedRole === "candidate" ? routes.candidateDashboard : routes.employerDashboard;
    setLoading(false);
    router.replace(searchParams.get("redirectTo") ?? destination);
    router.refresh();
  }

  async function continueSession() {
    setLoading(true);
    setError("");
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      setLoading(false);
      setError("No active session was found on this browser.");
      return;
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle<{ role: UserRole }>();

    setLoading(false);
    if (profileError || !profile) {
      setError(profileError?.message ?? "No Kaam role is linked to this session.");
      return;
    }

    router.replace(
      profile.role === "candidate" ? routes.candidateDashboard : routes.employerDashboard,
    );
    router.refresh();
  }

  return (
    <div className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <div className="grid grid-cols-2 gap-2" role="tablist" aria-label="Account type">
        {(["candidate", "employer"] as const).map((item) => (
          <button
            key={item}
            type="button"
            onClick={() => setRole(item)}
            className={`focus-ring rounded-lg px-4 py-3 text-sm font-semibold ${
              role === item
                ? "bg-[#e53670] text-white"
                : "bg-[#f7f2f5] text-[#3b3340]"
            }`}
          >
            {item === "candidate" ? "Candidate" : "Employer"}
          </button>
        ))}
      </div>

      <div className="mt-5 grid gap-3">
        <Label htmlFor="email">Email address</Label>
        <TextInput
          id="email"
          type="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="name@example.com"
          autoComplete="email"
          disabled={loading || step === "otp"}
        />

        {step === "otp" ? (
          <>
            <Label htmlFor="otp">OTP code</Label>
            <TextInput
              id="otp"
              value={otp}
              onChange={(event) => setOtp(event.target.value)}
              inputMode="numeric"
              autoComplete="one-time-code"
              placeholder="Enter code"
              disabled={loading}
            />
          </>
        ) : null}
      </div>

      {message ? <p className="mt-4 text-sm text-[#176b3b]">{message}</p> : null}
      {error ? <p className="mt-4 text-sm text-[#9a1744]">{error}</p> : null}

      <div className="mt-5 grid gap-3 sm:grid-cols-2">
        {step === "email" ? (
          <Button type="button" onClick={sendOtp} disabled={loading || !email.trim()}>
            {loading ? "Sending..." : "Send OTP"}
          </Button>
        ) : (
          <Button type="button" onClick={verifyOtp} disabled={loading || !otp.trim()}>
            {loading ? "Verifying..." : "Verify OTP"}
          </Button>
        )}
        <Button type="button" variant="secondary" onClick={continueSession} disabled={loading}>
          Continue existing session
        </Button>
      </div>

      <p className="mt-4 text-xs leading-5 text-[#66616f]">
        Kaam uses email OTP for this web foundation. Phone OTP and passwords are not enabled here.
      </p>
    </div>
  );
}
