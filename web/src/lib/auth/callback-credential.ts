export type AuthCallbackCredential =
  | { kind: "code"; value: string }
  | { kind: "magiclink"; value: string }
  | null;

export function authCallbackCredential(searchParams: URLSearchParams): AuthCallbackCredential {
  const code = searchParams.get("code");
  if (code) return { kind: "code", value: code };

  const tokenHash = searchParams.get("token_hash");
  if (tokenHash && searchParams.get("type") === "magiclink") {
    return { kind: "magiclink", value: tokenHash };
  }

  return null;
}
