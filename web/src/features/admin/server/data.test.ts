import { beforeEach, describe, expect, it, vi } from "vitest";
import { loadCandidates } from "./data";

const mockSupabase = {
  from: vi.fn(),
};

vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(async () => mockSupabase),
}));

function profileQuery(result: { data: unknown[] | null; error: unknown }) {
  const query = {
    select: vi.fn(() => query),
    eq: vi.fn(() => query),
    order: vi.fn(() => query),
    limit: vi.fn(async () => result),
  };
  return query;
}

describe("admin candidate data loader", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("starts from candidate-role profiles so employers and admins are excluded", async () => {
    const profiles = profileQuery({ data: [], error: null });
    mockSupabase.from.mockReturnValue(profiles);

    await loadCandidates({});

    expect(mockSupabase.from).toHaveBeenCalledWith("profiles");
    expect(profiles.eq).toHaveBeenCalledWith("role", "candidate");
  });

  it("returns an error state instead of converting query failure into an empty match state", async () => {
    const profiles = profileQuery({ data: null, error: { message: "permission denied" } });
    mockSupabase.from.mockReturnValue(profiles);

    const result = await loadCandidates({});

    expect(result.rows).toEqual([]);
    expect(result.errorMessage).toBe("Candidate accounts could not be loaded. Please try again.");
    expect(result.error).toBeTruthy();
  });
});

