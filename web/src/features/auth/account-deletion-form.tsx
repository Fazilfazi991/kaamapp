"use client";

import { FormEvent, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Label, TextInput } from "@/components/ui/form";
import { createBrowserSupabaseClient } from "@/lib/supabase/browser";
import { isValidEmail, normalizeOtp } from "@/lib/auth/routing";

const otpLength = Number(process.env.NEXT_PUBLIC_EMAIL_OTP_LENGTH ?? "6");

export function AccountDeletionForm({ configError }: { configError?: string | null }) {
  const supabase = useMemo(() => (configError ? null : createBrowserSupabaseClient()), [configError]);
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [step, setStep] = useState<"email" | "confirm">("email");
  const [loading, setLoading] = useState(false);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState(configError ?? "");

  function messageFrom(errorValue: unknown, fallback: string) {
    const text = errorValue && typeof errorValue === "object" && "message" in errorValue ? String(errorValue.message) : "";
    if (/network|fetch/i.test(text)) return "Network error. Check your connection and try again.";
    if (/invalid|token|expired/i.test(text)) return "That verification code is invalid or expired. Request a new code.";
    return fallback;
  }

  async function sendOtp(event: FormEvent) {
    event.preventDefault();
    if (!supabase || !isValidEmail(email)) { setError("Enter the email address on your KAAM account."); return; }
    setError(""); setNotice(""); setLoading(true);
    const { error: otpError } = await supabase.auth.signInWithOtp({ email: email.trim(), options: { shouldCreateUser: false } });
    setLoading(false);
    if (otpError) { setError(messageFrom(otpError, "We could not send a verification code. Please try again.")); return; }
    setStep("confirm"); setNotice("A verification code has been sent to your email.");
  }

  async function deleteAccount(event: FormEvent) {
    event.preventDefault();
    if (!supabase) return;
    if (otp.length !== otpLength) { setError(`Enter the ${otpLength}-digit verification code.`); return; }
    if (confirmation !== "DELETE") { setError("Type DELETE to confirm permanent account deletion."); return; }
    setError(""); setNotice(""); setLoading(true);
    const { data: verified, error: verifyError } = await supabase.auth.verifyOtp({ email: email.trim(), token: otp, type: "email" });
    if (verifyError || !verified.user) { setLoading(false); setError(messageFrom(verifyError, "We could not verify your email.")); return; }
    const { error: deletionError } = await supabase.functions.invoke("delete-account");
    if (deletionError) { setLoading(false); setError(messageFrom(deletionError, "We could not delete your account. Please try again or contact support.")); return; }
    await supabase.auth.signOut();
    setLoading(false); setNotice("Your KAAM account has been deleted."); setStep("email"); setOtp(""); setConfirmation("");
  }

  return <form onSubmit={step === "email" ? sendOtp : deleteAccount} className="mt-7 rounded-2xl border border-[#eadde3] bg-white p-5 shadow-sm">
    <Label htmlFor="deletion-email">Account email</Label><TextInput id="deletion-email" type="email" autoComplete="email" value={email} disabled={loading || step === "confirm"} onChange={(event) => setEmail(event.target.value.trimStart())} className="mt-2" />
    {step === "confirm" ? <><div className="mt-5"><Label htmlFor="deletion-otp">Verification code</Label><TextInput id="deletion-otp" value={otp} inputMode="numeric" autoComplete="one-time-code" onChange={(event) => setOtp(normalizeOtp(event.target.value).slice(0, otpLength))} className="mt-2" /></div><div className="mt-5"><Label htmlFor="delete-confirmation">Type DELETE to confirm</Label><TextInput id="delete-confirmation" value={confirmation} onChange={(event) => setConfirmation(event.target.value)} className="mt-2" /></div></> : null}
    {notice ? <p role="status" className="mt-4 rounded-lg bg-[#e7f7ee] px-3 py-2 text-sm text-[#176b3b]">{notice}</p> : null}{error ? <p role="alert" className="mt-4 rounded-lg bg-[#ffe4eb] px-3 py-2 text-sm text-[#9a1744]">{error}</p> : null}
    <Button type="submit" className="mt-5" disabled={loading || Boolean(configError)}>{loading ? "Please wait…" : step === "email" ? "Send verification code" : "Delete account permanently"}</Button>
  </form>;
}
