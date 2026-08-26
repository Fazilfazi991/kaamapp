type SupabaseAuthError = { code?: string; message?: string } | null | undefined;

export type OtpErrorPresentation = {
  message: string;
  suggestRegistration: boolean;
};

function details(error: unknown) {
  if (!error || typeof error !== "object") return { code: "", message: "" };
  const value = error as SupabaseAuthError;
  return { code: String(value?.code ?? "").toLowerCase(), message: String(value?.message ?? "").toLowerCase() };
}

export function otpErrorPresentation(operation: "request" | "verify", error: unknown): OtpErrorPresentation {
  const { code, message } = details(error);
  const combined = `${code} ${message}`;
  if (combined.includes("rate") || combined.includes("too many")) return { message: "Too many OTP requests. Please wait a little and try again.", suggestRegistration: false };
  if (operation === "verify" && (code === "otp_expired" || combined.includes("expired"))) return { message: "This OTP has expired. Request a new code.", suggestRegistration: false };
  if (operation === "verify" && (code === "invalid_token" || code === "invalid_credentials" || combined.includes("invalid") || combined.includes("token"))) return { message: "That OTP is incorrect. Please check the code and try again.", suggestRegistration: false };
  if (combined.includes("network") || combined.includes("fetch")) return { message: "Network error. Check your connection and try again.", suggestRegistration: false };
  if (operation === "request" && (code === "user_not_found" || combined.includes("user not found") || combined.includes("not registered") || combined.includes("signups not allowed") || combined.includes("social login"))) return { message: "We couldn’t send a login code for that account.", suggestRegistration: true };
  return { message: "We could not complete that authentication step. Please try again.", suggestRegistration: false };
}
