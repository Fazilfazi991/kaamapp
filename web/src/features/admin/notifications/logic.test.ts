import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { normalizeChannels, unavailablePushMessage } from "./logic";
import type { PushConfiguration } from "./types";

const pushUnavailable: PushConfiguration = {
  configured: false,
  status: "SERVER_CONFIG_MISSING",
  reason: unavailablePushMessage,
  setupHint: "setup",
};

const pushConfigured: PushConfiguration = {
  configured: true,
  status: "READY",
  reason: "",
  setupHint: "",
};

describe("admin notification channel logic", () => {
  it("removes unavailable push while preserving in-app delivery", () => {
    const result = normalizeChannels(["in_app", "push"], pushUnavailable);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.channels).toEqual(["in_app"]);
      expect(result.warning).toBe(unavailablePushMessage);
    }
  });

  it("rejects push-only sends when push is unavailable", () => {
    const result = normalizeChannels(["push"], pushUnavailable);

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.state.code).toBe("PUSH_NOT_CONFIGURED");
      expect(result.state.message).toBe(unavailablePushMessage);
    }
  });

  it("rejects no-channel submission with a clear error", () => {
    const result = normalizeChannels([], pushUnavailable);

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.state.code).toBe("NO_CHANNEL_SELECTED");
      expect(result.state.message).toBe(
        "Select at least one notification channel.",
      );
    }
  });

  it("keeps push when the complete push stack is configured", () => {
    const result = normalizeChannels(["in_app", "push"], pushConfigured);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.channels).toEqual(["in_app", "push"]);
      expect(result.warning).toBeUndefined();
    }
  });

  it("does not allow email or WhatsApp to masquerade as configured", () => {
    const result = normalizeChannels(["in_app", "email"], pushConfigured);

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.state.code).toBe("CHANNEL_NOT_CONFIGURED");
      expect(result.state.message).not.toContain("Supabase");
    }
  });

  it("keeps readiness states typed instead of collapsing unauthorized to not configured", () => {
    const unauthorized: PushConfiguration = {
      configured: false,
      status: "UNAUTHORIZED",
      reason: "Admin push health check is unauthorized.",
      setupHint: "Sign in again as an admin user.",
    };

    expect(unauthorized.status).toBe("UNAUTHORIZED");
    expect(unauthorized.reason).toContain("unauthorized");
  });

  it("uses insert for canonical notification rows to avoid partial-index upsert failure", () => {
    const source = readFileSync(
      "src/features/admin/notifications/server.ts",
      "utf8",
    );

    expect(source).toContain('.from("notifications")');
    expect(source).toContain(".insert(notificationRows)");
    expect(source).not.toContain('onConflict: "recipient_id,dedupe_key"');
    expect(source).toContain("RECIPIENT_NOTIFICATION_CREATE_FAILED");
  });
});
