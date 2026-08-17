"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Label, TextInput } from "@/components/ui/form";
import { routes } from "@/config/routes";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import {
  blockedAccountMessage,
  dashboardForRole,
  isBlockedStatus,
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
      .select("role,status")
      .eq("id", data.user.id)
      .maybeSingle<{ role: UserRole; status: string | null }>();

    if (roleResult.error) {
      setLoading(false);
      setError("We could not load your account role. Please try again.");
      return;
    }

    let backendRole = roleResult.data?.role ?? null;
    let backendStatus = roleResult.data?.status ?? null;
    if (!backendRole && mode === "register") {
      // This is the shared mobile/web account bootstrap contract. It obtains
      // the authenticated user from auth.uid(), creates exactly one profile,
      // and creates the candidate shell when appropriate. Do not duplicate
      // the profile insert in the browser.
      const bootstrap = await supabase
        .rpc("bootstrap_user_profile", { selected_role: role })
        .maybeSingle<{ role: UserRole; status: string | null }>();

      if (bootstrap.error || !bootstrap.data?.role) {
        setLoading(false);
        setError("We could not finish setting up your KAAM profile. Please try again.");
        return;
      }

      backendRole = bootstrap.data.role;
      backendStatus = bootstrap.data.status;
    }

    if (!backendRole) {
      setLoading(false);
      router.replace(routes.accountRecovery);
      router.refresh();
      return;
    }

    const account = {
      userId: data.user.id,
      email: data.user.email ?? null,
      role: backendRole,
      profileStatus: backendStatus,
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
    } else if (decision.status === "blocked") {
      setMessage(blockedAccountMessage);
    } else if (decision.message) {
      setMessage(decision.message);
    }

    const destination = new URL(
      decision.redirectTo ?? dashboardForRole(backendRole),
      window.location.origin,
    );
    if (mode === "register" && roleResult.data?.role) {
      destination.searchParams.set("authNotice", "existing-account");
    } else if (decision.message && decision.status !== "blocked") {
      destination.searchParams.set("authNotice", "role-redirect");
    }
    router.replace(`${destination.pathname}${destination.search}`);
    router.refresh();
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
      .select("role,status")
      .eq("id", user.id)
      .maybeSingle<{ role: UserRole; status: string | null }>();

    setLoading(false);
    if (profileError) {
      setError("We could not load your account role. Please try again.");
      return;
    }
    if (!profile?.role) {
      router.replace(routes.accountRecovery);
      router.refresh();
      return;
    }
    if (isBlockedStatus(profile.status)) {
      setMessage(blockedAccountMessage);
      router.replace(routes.accountBlocked);
      router.refresh();
      return;
    }

    router.replace(
      safeReturnPath(searchParams.get("redirectTo")) ?? dashboardForRole(profile.role),
    );
    router.refresh();
  }

  async function continueWithGoogle() {
    if (!supabase || loading) return;
    resetAlerts();
    setLoading(true);

    const callback = new URL(routes.authCallback, window.location.origin);
    const returnPath = safeReturnPath(searchParams.get("redirectTo"));
    if (returnPath) callback.searchParams.set("next", returnPath);

    const { error: oauthError } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: callback.toString() },
    });

    if (oauthError) {
      setLoading(false);
      setError(friendlyError("google_oauth", oauthError));
    }
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

      {step === "email" ? (
        <div className="mt-6">
          <div className="flex items-center gap-3" aria-hidden="true">
            <span className="h-px flex-1 bg-[#eadde3]" />
            <span className="text-xs font-medium uppercase tracking-wide text-[#766b74]">or</span>
            <span className="h-px flex-1 bg-[#eadde3]" />
          </div>
          <Button
            type="button"
            variant="secondary"
            onClick={continueWithGoogle}
            disabled={loading || Boolean(configError)}
            className="mt-4 w-full gap-3 border-[#d9d2d5] text-[#28222b] hover:bg-[#faf8f9]"
          >
            <GoogleIcon />
            {loading ? "Opening Google…" : "Continue with Google"}
          </Button>
        </div>
      ) : null}

      <p className="mt-4 text-xs leading-5 text-[#66616f]">
        Your selected tab is only the entry path. Kaam redirects using the backend role on your account.
      </p>
    </form>
  );
}

function GoogleIcon() {
  return (
    <svg aria-hidden="true" className="h-5 w-5" viewBox="0 0 24 24">
      <path fill="#4285F4" d="M21.35 12.23c0-.71-.06-1.39-.18-2.04H12v3.86h5.24a4.48 4.48 0 0 1-1.94 2.94v2.5h3.14c1.84-1.69 2.91-4.19 2.91-7.26Z" />
      <path fill="#34A853" d="M12 21.75c2.63 0 4.84-.87 6.45-2.36l-3.14-2.4c-.87.58-1.99.92-3.31.92-2.54 0-4.69-1.72-5.46-4.03H3.3v2.48A9.75 9.75 0 0 0 12 21.75Z" />
      <path fill="#FBBC05" d="M6.54 13.88A5.86 5.86 0 0 1 6.24 12c0-.65.11-1.28.3-1.88V7.64H3.3A9.75 9.75 0 0 0 2.25 12c0 1.57.38 3.05 1.05 4.36l3.24-2.48Z" />
      <path fill="#EA4335" d="M12 6.09c1.43 0 2.71.49 3.72 1.45l2.79-2.79C16.84 3.19 14.63 2.25 12 2.25a9.75 9.75 0 0 0-8.7 5.39l3.24 2.48C7.31 7.81 9.46 6.09 12 6.09Z" />
    </svg>
  );
}
