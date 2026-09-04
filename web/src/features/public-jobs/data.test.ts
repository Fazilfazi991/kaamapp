import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const rpc = vi.fn();

vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(async () => ({ rpc })),
}));

describe("public jobs loader", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
    vi.spyOn(console, "info").mockImplementation(() => undefined);
    vi.spyOn(console, "warn").mockImplementation(() => undefined);
    delete process.env.KAAM_PUBLIC_JOBS_DEMO;
    process.env.VERCEL_ENV = "preview";
  });

  afterEach(() => {
    vi.restoreAllMocks();
    delete process.env.KAAM_PUBLIC_JOBS_DEMO;
    delete process.env.VERCEL_ENV;
  });

  it("uses deterministic demo jobs when the Preview fixture flag is enabled", async () => {
    process.env.KAAM_PUBLIC_JOBS_DEMO = "true\n";
    const { loadPublicHiringRequirements } = await import("./data");

    const jobs = await loadPublicHiringRequirements(3);

    expect(jobs).toHaveLength(3);
    expect(jobs.every((job) => job.id.startsWith("demo-"))).toBe(true);
    expect(rpc).not.toHaveBeenCalled();
    expect(console.info).toHaveBeenCalledWith("[PublicJobs] load", {
      source: "demo",
      count: 3,
      status: "ok",
      environment: "preview",
    });
  });

  it("reports live query failures without logging database details", async () => {
    rpc.mockResolvedValue({ data: null, error: { message: "sensitive detail" } });
    const { loadPublicHiringRequirements } = await import("./data");

    await expect(loadPublicHiringRequirements(12)).resolves.toEqual([]);
    expect(console.warn).toHaveBeenCalledWith("[PublicJobs] load", {
      source: "live",
      count: 0,
      status: "rpc_error",
      environment: "preview",
    });
    expect(JSON.stringify(vi.mocked(console.warn).mock.calls)).not.toContain("sensitive detail");
  });
});
