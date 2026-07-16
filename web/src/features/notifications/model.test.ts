import { describe, expect, it } from "vitest";
import { safeNotificationHref, sanitizePushPayload } from "./model";

describe("notification model", () => {
  it("rejects external and wrong-role routes", () => {
    expect(
      safeNotificationHref({
        role: "candidate",
        type: "unknown",
        actionRoute: "https://example.com",
      }),
    ).toBe("/candidate/notifications");
    expect(
      safeNotificationHref({
        role: "candidate",
        type: "unknown",
        actionRoute: "/employer/matches",
      }),
    ).toBe("/candidate/notifications");
  });

  it("maps supported notification types to safe internal pages", () => {
    expect(
      safeNotificationHref({
        role: "candidate",
        type: "new_message",
      }),
    ).toBe("/candidate/messages");
    expect(
      safeNotificationHref({
        role: "admin",
        type: "employer_document_submitted",
      }),
    ).toBe("/admin/employer-documents");
  });

  it("removes sensitive payload fields", () => {
    expect(
      sanitizePushPayload({
        notification_id: "n1",
        message_body: "private",
        storage_path: "secret/path",
        match_id: "m1",
      }),
    ).toEqual({ notification_id: "n1", match_id: "m1" });
  });
});
