import { describe, expect, it } from "vitest";
import { oauthCallbackUrl } from "./oauth-redirect";

describe("oauthCallbackUrl", () => {
  it("uses the configured canonical KAAM host for production", () => {
    expect(oauthCallbackUrl({
      currentOrigin: "https://kaamcareer.com",
      configuredSiteUrl: "https://www.kaamcareer.com",
    })).toBe("https://www.kaamcareer.com/auth/callback");
  });

  it("rejects a stale Vercel URL as the production callback", () => {
    expect(oauthCallbackUrl({
      currentOrigin: "https://www.kaamcareer.com",
      configuredSiteUrl: "https://kaamapp.vercel.app",
    })).toBe("https://www.kaamcareer.com/auth/callback");
  });

  it("keeps local and preview environments on their current origin", () => {
    expect(oauthCallbackUrl({
      currentOrigin: "http://localhost:3000",
      configuredSiteUrl: "https://www.kaamcareer.com",
    })).toBe("http://localhost:3000/auth/callback");
  });
});
