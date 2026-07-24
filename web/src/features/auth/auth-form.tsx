"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Label, TextInput } from "@/components/ui/form";
import { routes } from "@/config/routes";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import {
  dashboardForRole,
  isValidEmail,
  normalizeOtp,
  postOtpDestination,
  safeReturnPath,
  type AppAccountRole,
} from "@/lib/auth/routing";
import type { UserRole } from "@/types/domain";

type Step = "email" | "otp";
type AuthMode = "login" | "register";

const otpLength = Number(process.env.NEXT_PUBLIC_EMAIL_OTP_LENGTH ?? "6");
const resendCooldownSeconds = 45;

export function AuthForm({
  initialRole = "candidate",
  mode = "login",
  configError,
}: {
  initialRole?: AppAccountRole;
  mode?: AuthMode;
  configError?: string | null;
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const supabase = useMemo(
    () => (configError ? null : createBrowserSupabaseClient()),
    [configError],
  );
  const [role, setRole] = useState<AppAccountRole>(initialRole);
  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState(configError ?? "");
  const [loading, setLoading] = useState(false);
  const [cooldownUntil, setCooldownUntil] = useState<number | null>(null);
  const [now, setNow] = useState(0);

  const cooldownRemaining = cooldownUntil
    ? Math.max(0, Math.ceil((cooldownUntil - now) / 1000))
    : 0;
  const trimmedEmail = email.trim();
  const canSend = Boolean(
    supabase && isValidEmail(trimmedEmail) && !loading && cooldownRemaining === 0,
  );
  const canVerify = Boolean(
    supabase && otp.length === otpLength && !loading,
  );

  useEffect(() => {
    if (!cooldownUntil) return;
    const timer = window.setInterval(() => {
      const current = Date.now();
      setNow(current);
      if (current >= cooldownUntil) {
        setCooldownUntil(null);
      }
    }, 1000);
    return () => window.clearInterval(timer);
  }, [cooldownUntil]);

  function resetAlerts() {
    setError("");
    setMessage("");
  }

  function friendlyError(operation: string, cause: unknown) {
    const rawMessage =
      cause && typeof cause === "object" && "message" in cause
        ? String(cause.message)
        : "";
    const lower = rawMessage.toLowerCase();

    if (lower.includes("rate") || lower.includes("too many")) {
      return "Too many OTP requests. Please wait a little and try again.";
    }
    if (lower.includes("expired")) return "This OTP has expired. Request a new code.";
    if (lower.includes("invalid") || lower.includes("token")) {
      return "The OTP code is incorrect. Check the email and try again.";
    }
    if (lower.includes("network") || lower.includes("fetch")) {
      return "Network error. Check your connection and try again.";
    }

    if (process.env.NODE_ENV !== "production") {
      console.debug("[auth]", { operation, category: "supabase_error" });
    }
    return "We could not complete that authentication step. Please try again.";
  }

  async function sendOtp() {
    if (!supabase) return;
    resetAlerts();
    if (!isValidEmail(trimmedEmail)) {
      setError("Enter a valid email address.");
      return;
    }

    setLoading(true);
    const { error: otpError } = await supabase.auth.signInWithOtp({
      email: trimmedEmail,
      options: {
        shouldCreateUser: true,
        data: { role },
      },
    });
    setLoading(false);

    if (otpError) {
      setError(friendlyError("request_otp", otpError));
      return;
    }

    const sentAt = Date.now();
    setNow(sentAt);
    setCooldownUntil(sentAt + resendCooldownSeconds * 1000);
    setStep("otp");
    setMessage("OTP sent. Enter the code from your email.");
  }

  async function verifyOtp() {
    if (!supabase) return;
    resetAlerts();
    if (otp.length !== otpLength) {
      setError(`Enter the ${otpLength}-digit OTP code.`);
      return;
    }

    setLoading(true);
    const { data, error: verifyError } = await supabase.auth.verifyOtp({
      email: trimmedEmail,
      token: otp,
      type: "email",
    });

    if (verifyError || !data.user) {
      setLoading(false);
      setOtp("");
      setError(friendlyError("verify_otp", verifyError));
      return;
    }

    const roleResult = await supabase
      .from("profiles")
      .select("role")
      .eq("id", data.user.id)
      .maybeSingle<{ role: UserRole }>();

    if (roleResult.error) {
      setLoading(false);
      setError("We could not load your account role. Please try again.");
      return;
    }

    let backendRole = roleResult.data?.role ?? null;
    if (!backendRole && mode === "register") {
      const insertResult = await supabase.from("profiles").insert({
        id: data.user.id,
        role,
        email: data.user.email,
        status: "active",
      });

      if (insertResult.error) {
        const retry = await supabase
          .from("profiles")
          .select("role")
          .eq("id", data.user.id)
          .maybeSingle<{ role: UserRole }>();
        backendRole = retry.data?.role ?? null;
      } else {
        backendRole = role;
      }
    }

    if (!backendRole) {
      setLoading(false);
      router.replace(routes.accountRecovery);
      return;
    }

    const account = {
      userId: data.user.id,
      email: data.user.email ?? null,
      role: backendRole,
      hasCandidateProfile: false,
      hasEmployerProfile: false,
    };
    const decision = postOtpDestination(
      account,
      role,
      searchParams.get("redirectTo"),
    );
    setLoading(false);
    setOtp("");

    if (mode === "register" && roleResult.data?.role) {
      setMessage("This email is already registered. Continuing to the existing account.");
    } else if (decision.message) {
      setMessage(decision.message);
    }

    const destination = new URL(
      decision.redirectTo ?? dashboardForRole(backendRole),
      window.location.origin,
    );
    if (mode === "register" && roleResult.data?.role) {
      destination.searchParams.set("authNotice", "existing-account");
    } else if (decision.message) {
      destination.searchParams.set("authNotice", "role-redirect");
    }
    router.replace(`${destination.pathname}${destination.search}`);
  }

  async function continueSession() {
    if (!supabase) return;
    setLoading(true);
    resetAlerts();
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
    if (profileError) {
      setError("We could not load your account role. Please try again.");
      return;
    }
    if (!profile?.role) {
      router.replace(routes.accountRecovery);
      return;
    }

    router.replace(
      safeReturnPath(searchParams.get("redirectTo")) ?? dashboardForRole(profile.role),
    );
  }

  function changeEmail() {
    setStep("email");
    setOtp("");
    setCooldownUntil(null);
    resetAlerts();
  }

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (step === "email") void sendOtp();
    if (step === "otp") void verifyOtp();
  }

  return (
    <form
      onSubmit={onSubmit}
      className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm"
    >
      <div className="grid grid-cols-2 gap-2" role="tablist" aria-label="Account type">
        {(["candidate", "employer"] as const).map((item) => (
          <button
            key={item}
            type="button"
            onClick={() => setRole(item)}
            aria-pressed={role === item}
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
          onChange={(event) => setEmail(event.target.value.trimStart())}
          placeholder="name@example.com"
          autoComplete="email"
          autoFocus
          disabled={loading || step === "otp" || Boolean(configError)}
        />

        {step === "otp" ? (
          <>
            <div className="flex items-center justify-between gap-3">
              <Label htmlFor="otp">OTP code</Label>
              <button
                type="button"
                onClick={changeEmail}
                className="focus-ring rounded-md text-sm font-semibold text-[#bc1f55]"
                disabled={loading}
              >
                Change email
              </button>
            </div>
            <TextInput
              id="otp"
              value={otp}
              onChange={(event) =>
                setOtp(normalizeOtp(event.target.value).slice(0, otpLength))
              }
              inputMode="numeric"
              autoComplete="one-time-code"
              placeholder={`${otpLength}-digit code`}
              disabled={loading}
              autoFocus
            />
          </>
        ) : null}
      </div>

      {message ? (
        <p className="mt-4 rounded-lg bg-[#e7f7ee] px-3 py-2 text-sm text-[#176b3b]">
          {message}
        </p>
      ) : null}
      {error ? (
        <p className="mt-4 rounded-lg bg-[#ffe4eb] px-3 py-2 text-sm text-[#9a1744]">
          {error}
        </p>
      ) : null}

      <div className="mt-5 grid gap-3 sm:grid-cols-2">
        {step === "email" ? (
          <Button type="submit" disabled={!canSend}>
            {loading ? "Sending..." : "Send OTP"}
          </Button>
        ) : (
          <Button type="submit" disabled={!canVerify}>
            {loading ? "Verifying..." : "Verify OTP"}
          </Button>
        )}
        {step === "otp" ? (
          <Button
            type="button"
            variant="secondary"
            onClick={sendOtp}
            disabled={loading || cooldownRemaining > 0}
          >
            {cooldownRemaining > 0
              ? `Resend in ${cooldownRemaining}s`
              : "Resend OTP"}
          </Button>
        ) : (
          <Button
            type="button"
            variant="secondary"
            onClick={continueSession}
            disabled={loading || Boolean(configError)}
          >
            Continue existing session
          </Button>
        )}
      </div>

      <p className="mt-4 text-xs leading-5 text-[#66616f]">
        Your selected tab is only the entry path. Kaam redirects using the backend role on your account.
      </p>
    </form>
  );
}
