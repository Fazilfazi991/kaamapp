export function AuthNotice({ code }: { code?: string }) {
  const message =
    code === "role-redirect"
      ? "This account is registered with a different role. We redirected you to the correct dashboard."
      : code === "existing-account"
        ? "This email is already registered. Continuing to the existing account."
        : "";

  if (!message) return null;

  return (
    <p className="rounded-lg bg-[#e7f7ee] px-4 py-3 text-sm font-semibold text-[#176b3b]">
      {message}
    </p>
  );
}
