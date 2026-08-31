import { describe, expect, it } from "vitest";
import { authCallbackCredential } from "@/lib/auth/callback-credential";

describe("authCallbackCredential", () => {
  it("prefers a PKCE authorization code", () => {
    expect(authCallbackCredential(new URLSearchParams("code=pkce-code&token_hash=hash&type=magiclink")))
      .toEqual({ kind: "code", value: "pkce-code" });
  });

  it("accepts a one-time Supabase magic-link token hash", () => {
    expect(authCallbackCredential(new URLSearchParams("token_hash=hashed-token&type=magiclink")))
      .toEqual({ kind: "magiclink", value: "hashed-token" });
  });

  it("rejects unsupported token verification types", () => {
    expect(authCallbackCredential(new URLSearchParams("token_hash=hashed-token&type=recovery")))
      .toBeNull();
  });
});
