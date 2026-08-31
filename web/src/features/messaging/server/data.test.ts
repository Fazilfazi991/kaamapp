import { beforeEach, describe, expect, it, vi } from "vitest";
import { buildConversationSummaries, loadConversationSummaries } from "./data";

const mocks = vi.hoisted(() => ({
  getAuthenticatedProfile: vi.fn(),
  redirect: vi.fn((path: string) => {
    throw new Error(`redirect:${path}`);
  }),
  rpc: vi.fn(),
  from: vi.fn(),
}));

vi.mock("next/navigation", () => ({ redirect: mocks.redirect }));
vi.mock("@/lib/auth/session", () => ({ getAuthenticatedProfile: mocks.getAuthenticatedProfile }));
vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: vi.fn(async () => ({ rpc: mocks.rpc, from: mocks.from })),
}));

function messageQuery(data: unknown[]) {
  const query = {
    select: vi.fn(() => query),
    in: vi.fn(() => query),
    returns: vi.fn(async () => ({ data, error: null })),
  };
  return query;
}

const candidateMatch = {
  match_id: "match-1",
  company_name: "Example Company",
  role: "Engineer",
  location: "Dubai",
  matched_at: "2026-01-01T00:00:00Z",
  chat_enabled: true,
};

const employerMatch = {
  match_id: "match-1",
  candidate_id: "candidate-12345678",
  display_name: "Candidate One",
  role: "Engineer",
  location: "Dubai",
  matched_at: "2026-01-01T00:00:00Z",
  chat_enabled: true,
};

describe("messaging inbox authorization and batching", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.from.mockReturnValue(messageQuery([]));
  });

  it("loads a Candidate inbox through one match RPC and one batched message query", async () => {
    mocks.getAuthenticatedProfile.mockResolvedValue({
      user: { id: "candidate-1" },
      profile: { role: "candidate", status: "active" },
    });
    mocks.rpc.mockResolvedValue({ data: [candidateMatch], error: null });

    const result = await loadConversationSummaries("candidate");

    expect(result).toHaveLength(1);
    expect(mocks.rpc).toHaveBeenCalledTimes(1);
    expect(mocks.rpc).toHaveBeenCalledWith("candidate_matches_with_access");
    expect(mocks.from).toHaveBeenCalledTimes(1);
    expect(mocks.from).toHaveBeenCalledWith("chat_messages");
  });

  it("loads an Employer inbox through one match RPC and one batched message query", async () => {
    mocks.getAuthenticatedProfile.mockResolvedValue({
      user: { id: "employer-1" },
      profile: { role: "employer", status: "active" },
    });
    mocks.rpc.mockResolvedValue({ data: [employerMatch], error: null });

    const result = await loadConversationSummaries("employer");

    expect(result[0].title).toBe("Candidate One");
    expect(mocks.rpc).toHaveBeenCalledWith("employer_matches_with_contact");
    expect(mocks.rpc).toHaveBeenCalledTimes(1);
    expect(mocks.from).toHaveBeenCalledTimes(1);
  });

  it("denies a Candidate attempting to load the Employer inbox", async () => {
    mocks.getAuthenticatedProfile.mockResolvedValue({
      user: { id: "candidate-1" },
      profile: { role: "candidate", status: "active" },
    });

    await expect(loadConversationSummaries("employer")).rejects.toThrow("redirect:/employer/dashboard");
    expect(mocks.rpc).not.toHaveBeenCalled();
    expect(mocks.from).not.toHaveBeenCalled();
  });
});

describe("messaging summary correctness", () => {
  it("uses the newest message and counts only unread messages from the other participant", () => {
    const result = buildConversationSummaries("candidate", "candidate-1", [candidateMatch], [
      { match_id: "match-1", sender_id: "employer-1", body: "older", is_read: false, created_at: "2026-01-01T10:00:00Z" },
      { match_id: "match-1", sender_id: "candidate-1", body: "latest", is_read: false, created_at: "2026-01-01T11:00:00Z" },
      { match_id: "match-1", sender_id: "employer-1", body: "read", is_read: true, created_at: "2026-01-01T09:00:00Z" },
    ]);

    expect(result[0]).toMatchObject({
      title: "Example Company",
      subtitle: "Engineer - Dubai",
      lastMessage: "latest",
      lastMessageAt: "2026-01-01T11:00:00Z",
      unreadCount: 1,
    });
  });

  it("keeps an empty conversation visible with the existing empty state", () => {
    const result = buildConversationSummaries("candidate", "candidate-1", [candidateMatch], []);

    expect(result[0]).toMatchObject({ lastMessage: "No messages yet.", lastMessageAt: null, unreadCount: 0 });
  });

  it("batches multiple conversations without duplicates and sorts by latest activity", () => {
    const second = { ...candidateMatch, match_id: "match-2", company_name: "Second Company" };
    const result = buildConversationSummaries("candidate", "candidate-1", [candidateMatch, second], [
      { match_id: "match-1", sender_id: "employer-1", body: "first", is_read: true, created_at: "2026-01-01T10:00:00Z" },
      { match_id: "match-2", sender_id: "employer-2", body: "second", is_read: false, created_at: "2026-01-02T10:00:00Z" },
    ]);

    expect(result.map((item) => item.matchId)).toEqual(["match-2", "match-1"]);
    expect(new Set(result.map((item) => item.matchId)).size).toBe(2);
  });
});
