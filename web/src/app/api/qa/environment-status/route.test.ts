import { afterEach, describe, expect, it } from "vitest";
import { GET, previewEnvironmentStatus } from "./route";

const originalEnvironment = { ...process.env };

afterEach(() => {
  process.env = { ...originalEnvironment };
});

describe("Preview environment status", () => {
  it("classifies QA Supabase and Stripe test mode without returning secrets", () => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://skswbbcimwvwmuiapjnd.supabase.co";
    process.env.STRIPE_SECRET_KEY = "sk_test_not-a-real-secret";

    expect(previewEnvironmentStatus()).toEqual({
      supabase: "QA",
      supabaseProjectRef: "skswbbcimwvwmuiapjnd",
      stripe: "TEST",
    });
    expect(JSON.stringify(previewEnvironmentStatus())).not.toContain("not-a-real-secret");
  });

  it("classifies the known Production Supabase target and live Stripe mode", () => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://bhuhojzqxnvwbsypijac.supabase.co";
    process.env.STRIPE_SECRET_KEY = "sk_live_not-a-real-secret";

    expect(previewEnvironmentStatus()).toEqual({
      supabase: "PRODUCTION",
      supabaseProjectRef: "bhuhojzqxnvwbsypijac",
      stripe: "LIVE",
    });
  });

  it("is unavailable outside Vercel Preview", async () => {
    process.env.VERCEL_ENV = "production";
    expect((await GET()).status).toBe(404);
  });

  it("returns only safe classifications in Preview", async () => {
    process.env.VERCEL_ENV = "preview";
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://bhuhojzqxnvwbsypijac.supabase.co";
    process.env.STRIPE_SECRET_KEY = "sk_test_not-a-real-secret";
    const response = await GET();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store, max-age=0");
    await expect(response.json()).resolves.toEqual({
      supabase: "PRODUCTION",
      supabaseProjectRef: "bhuhojzqxnvwbsypijac",
      stripe: "TEST",
    });
  });
});
