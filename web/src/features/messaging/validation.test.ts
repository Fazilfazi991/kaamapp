import { describe, expect, it } from "vitest";
import {
  dedupeMessages,
  maxMessageLength,
  normalizeMessageBody,
  shouldAcceptRealtimeEvent,
  validateMessageBody,
} from "./validation";

describe("messaging validation", () => {
  it("trims surrounding whitespace while preserving line breaks", () => {
    expect(normalizeMessageBody("  hello\nthere  ")).toBe("hello\nthere");
  });

  it("rejects empty messages", () => {
    expect(validateMessageBody("").ok).toBe(false);
  });

  it("rejects whitespace-only messages", () => {
    expect(validateMessageBody("   \n\t  ").ok).toBe(false);
  });

  it("rejects oversized messages", () => {
    expect(validateMessageBody("x".repeat(maxMessageLength + 1)).ok).toBe(false);
  });

  it("accepts valid messages", () => {
    expect(validateMessageBody("Hello").ok).toBe(true);
  });

  it("keeps sender content as text-compatible strings", () => {
    const result = validateMessageBody("<script>alert(1)</script>");
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value).toBe("<script>alert(1)</script>");
  });

  it("deduplicates messages by stable id", () => {
    expect(dedupeMessages([{ id: "1" }, { id: "1" }, { id: "2" }])).toHaveLength(2);
  });

  it("accepts realtime events for the active conversation", () => {
    expect(shouldAcceptRealtimeEvent("match-1", "match-1")).toBe(true);
  });

  it("ignores realtime events from another conversation", () => {
    expect(shouldAcceptRealtimeEvent("match-2", "match-1")).toBe(false);
  });
});
