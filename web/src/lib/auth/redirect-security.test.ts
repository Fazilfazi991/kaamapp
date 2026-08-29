import { describe, expect, it } from "vitest";
import { safeReturnPath } from "./routing";

describe("auth redirect security", () => {
  it.each([
    "https://evil.example/phish",
    "//evil.example/phish",
    "/%2F%2Fevil.example/phish",
    "/%252F%252Fevil.example/phish",
    "%2F%2Fevil.example/phish",
  ])("rejects an unsafe return URL: %s", (value) => {
    expect(safeReturnPath(value)).toBeNull();
  });
});
