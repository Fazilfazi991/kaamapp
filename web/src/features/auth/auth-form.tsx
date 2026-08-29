"use client";

import { FormEvent, useEffect, useMemo, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Label, TextInput } from "@/components/ui/form";
import { routes } from "@/config/routes";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import { oauthCallbackUrl } from "@/lib/auth/oauth-redirect";
import {
  authenticatedEntryDestination,
  authJourney,
  blockedAccountMessage,
  dashboardForRole,
  isBlockedStatus,
  isValidEmail,
  loginForRole,
  normalizeOtp,
  registerForRole,
  safeReturnPath,
  type AppAccountRole,
  type AuthMode,
} from "@/lib/auth/routing";
import type { UserRole } from "@/types/domain";
import { linkAnalyticsIdentity, track } from "@/features/analytics/tracker";
import { otpErrorPresentation } from "@/features/auth/otp-errors";

type Step = "email" | "otp";

const otpLength = Number(process.env.NEXT_PUBLIC_EMAIL_OTP_LENGTH ?? "6");
const resendCooldownSeconds = 45;

export function AuthForm({
  role,
  mode,
  configError,
}: {
  role: AppAccountRole;
  mode: AuthMode;
  configError?: string | null;
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const supabase = useMemo(
    () => (configError ? null : createBrowserSupabaseClient()),
    [configError],
  );
  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState(configError ?? "");
  const [loading, setLoading] = useState(false);
  const [cooldownUntil, setCooldownUntil] = useState<number | null>(null);
  const [now, setNow] = useState(0);
  const otpRequestInFlight = useRef(false);
  const otpVerificationInFlight = useRef(false);
  const registrationStarted = useRef(false);
  const [suggestRegistration, setSuggestRegistration] = useState(false);

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
    setSuggestRegistration(false);
  }

  function trackRegistrationStarted(authMethod: "otp" | "google") {
    if (mode !== "register" || registrationStarted.current) return;
    registrationStarted.current = true;
    track("registration_started", { account_type: role, auth_method: authMethod });
  }

  async function sendOtp() {
    if (!supabase || loading || otpRequestInFlight.current) return;
    resetAlerts();
    if (!isValidEmail(trimmedEmail)) {
      setError("Enter a valid email address.");
      return;
    }

    trackRegistrationStarted("otp");
    otpRequestInFlight.current = true;
    setLoading(true);
    const { error: otpError } = await supabase.auth.signInWithOtp({
      email: trimmedEmail,
      options: {
        shouldCreateUser: mode === "register",
        data: { role },
      },
    });
    otpRequestInFlight.current = false;
    setLoading(false);

    if (otpError) {
      const presentation = otpErrorPresentation("request", otpError);
      setError(presentation.message);
      setSuggestRegistration(mode === "login" && presentation.suggestRegistration);
      return;
    }

    track("otp_requested", { flow: mode === "login" ? "login" : "registration", account_type: role });

    const sentAt = Date.now();
    setNow(sentAt);
    setCooldownUntil(sentAt + resendCooldownSeconds * 1000);
    setOtp("");
    setStep("otp");
    setMessage("OTP sent. Enter the code from your email.");
  }

  async function verifyOtp() {
    if (!supabase || loading || otpVerificationInFlight.current) return;
    resetAlerts();
    if (otp.length !== otpLength) {
      setError(`Enter the ${otpLength}-digit OTP code.`);
      return;
    }

    otpVerificationInFlight.current = true;
    setLoading(true);
    const { data, error: verifyError } = await supabase.auth.verifyOtp({
      email: trimmedEmail,
      token: otp,
      type: "email",
    });

    if (verifyError || !data.user) {
      setLoading(false);
      setOtp("");
      otpVerificationInFlight.current = false;
      setError(otpErrorPresentation("verify", verifyError).message);
      return;
    }

    otpVerificationInFlight.current = false;
    track("otp_verified", { flow: mode === "login" ? "login" : "registration" });

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
    const isNewRoleSelection = !backendRole && mode === "register";
    if (isNewRoleSelection) {
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
      await supabase.auth.signOut({ scope: "local" });
      setSuggestRegistration(mode === "login");
      setError(
        mode === "login"
          ? `We couldn't find a ${role === "candidate" ? "Candidate" : "Employer"} account for this email.`
          : "We could not finish setting up your KAAM account. Please try again.",
      );
      return;
    }

    if (backendRole !== "admin") linkAnalyticsIdentity(backendRole);
    if (isNewRoleSelection) track("account_type_selected", { account_type: backendRole as "candidate" | "employer" });
    track(mode === "register" ? "registration_completed" : "login", { role: backendRole });
    if (mode === "login") track("login_success", { auth_method: "otp", account_type: backendRole });
    setLoading(false);
    setOtp("");

    if (mode === "register" && roleResult.data?.role) {
      setMessage("This email is already registered. Continuing to the existing account.");
    } else if (isBlockedStatus(backendStatus)) {
      setMessage(blockedAccountMessage);
    } else if (backendRole !== role) {
      setMessage(`This account is registered as a ${backendRole}.`);
    }

    const destination = new URL(
      isBlockedStatus(backendStatus)
        ? routes.accountBlocked
        : backendRole !== role
          ? dashboardForRole(backendRole)
          : authenticatedEntryDestination(backendRole, searchParams.get("redirectTo")),
      window.location.origin,
    );
    if (mode === "register" && roleResult.data?.role) {
      destination.searchParams.set("authNotice", "existing-account");
    } else if (backendRole !== role && !isBlockedStatus(backendStatus)) {
      destination.searchParams.set("authNotice", "role-redirect");
    }
    router.replace(`${destination.pathname}${destination.search}`);
    router.refresh();
  }

  async function continueWithGoogle() {
    if (!supabase || loading) return;
    resetAlerts();
    setLoading(true);
    trackRegistrationStarted("google");

    const callback = new URL(oauthCallbackUrl({
      currentOrigin: window.location.origin,
      configuredSiteUrl: process.env.NEXT_PUBLIC_SITE_URL,
    }));
    const returnPath = safeReturnPath(searchParams.get("redirectTo"));
    if (returnPath) callback.searchParams.set("next", returnPath);
    callback.searchParams.set("journey", authJourney(role, mode));

    const { error: oauthError } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: callback.toString(),
        queryParams: { prompt: "select_account" },
      },
    });

    if (oauthError) {
      setLoading(false);
      setError(otpErrorPresentation("request", oauthError).message);
      return;
    }
    track("google_auth_started", { flow: mode === "login" ? "login" : "registration", account_type: role });
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
      className="rounded-2xl border border-[#eadde3] bg-white p-5 shadow-[0_18px_42px_rgba(74,35,54,.10)] sm:p-6"
    >
      <div className="grid gap-3.5">
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
                className="focus-ring rounded-md text-sm font-semibold text-[#160847]"
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
        <div className="mt-4 rounded-lg bg-[#ffe4eb] px-3 py-2 text-sm text-[#9a1744]">
          <p>{error}</p>
          {suggestRegistration ? <Link href={registerForRole(role)} className="mt-2 inline-block font-semibold underline underline-offset-4">Register as {role === "candidate" ? "a Candidate" : "an Employer"}</Link> : null}
        </div>
      ) : null}

      <div className="mt-5 grid gap-3">
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
        ) : null}
      </div>

      {step === "email" ? (
        <div className="mt-5">
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
            className="mt-4 w-full gap-3 border-[#160847] text-[#160847] hover:bg-[#f7f4ff]"
          >
            <GoogleIcon />
            {loading ? "Opening Google…" : "Continue with Google"}
          </Button>
        </div>
      ) : null}

      <p className="mt-5 text-center text-sm leading-6 text-[#615667]">
        {mode === "login" ? "New to KAAM?" : "Already registered?"}{" "}
        <Link href={mode === "login" ? registerForRole(role) : loginForRole(role)} className="font-semibold text-[#160847] underline decoration-[#f56ba1] decoration-2 underline-offset-4">
          {mode === "login" ? `Register as ${role === "candidate" ? "a Candidate" : "an Employer"}` : `${role === "candidate" ? "Candidate" : "Employer"} login`}
        </Link>
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
