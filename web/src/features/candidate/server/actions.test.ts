import { beforeEach, describe, expect, it, vi } from "vitest";
import { saveLocationDetails } from "./actions";

const { redirect, revalidatePath, getClaims, maybeSingle, select, eq, update, from } = vi.hoisted(() => {
  const redirect = vi.fn(() => {
    throw new Error("NEXT_REDIRECT");
  });
  const revalidatePath = vi.fn();
  const getClaims = vi.fn(async () => ({ data: { claims: { sub: "candidate-1" } }, error: null }));
  const maybeSingle = vi.fn(async () => ({ data: { id: "candidate-1" }, error: null }));
  const select = vi.fn(() => ({ maybeSingle }));
  const eq = vi.fn(() => ({ select }));
  const update = vi.fn(() => ({ eq }));
  const from = vi.fn(() => ({ update }));
  return { redirect, revalidatePath, getClaims, maybeSingle, select, eq, update, from };
});

vi.mock("next/navigation", () => ({ redirect }));
vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("@/lib/auth/session", () => ({
  requireRole: vi.fn(async () => ({ userId: "candidate-1", role: "candidate", email: "candidate@example.com" })),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(async () => ({ auth: { getClaims }, from })),
}));

describe("saveLocationDetails", () => {
  beforeEach(() => vi.clearAllMocks());

  it("performs one location update then redirects without profile upsert or broad revalidation", async () => {
    const formData = new FormData();
    formData.set("currentCountry", "India");
    formData.set("currentRegion", "Kerala");
    formData.set("preferredCountry", "Saudi Arabia");
    formData.set("preferredRegion", "");

    await expect(saveLocationDetails({ error: null }, formData)).rejects.toThrow("NEXT_REDIRECT");

    expect(from).toHaveBeenCalledTimes(1);
    expect(getClaims).toHaveBeenCalledTimes(1);
    expect(from).toHaveBeenCalledWith("candidate_profiles");
    expect(update).toHaveBeenCalledWith({
      current_country: "India",
      current_city: "Kerala",
      preferred_country: "Saudi Arabia",
      preferred_city: null,
    });
    expect(eq).toHaveBeenCalledWith("id", "candidate-1");
    expect(select).toHaveBeenCalledWith("id");
    expect(maybeSingle).toHaveBeenCalledTimes(1);
    expect(revalidatePath).not.toHaveBeenCalled();
    expect(redirect).toHaveBeenCalledWith("/candidate/onboarding/experience");
  });
});
