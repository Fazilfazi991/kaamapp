import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import {
  canEnablePushChannel,
  normalizeChannels,
  pushReadinessLabel,
  selectedActiveAndroidDeviceCount,
  unavailablePushMessage,
} from "./logic";
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
    expect(pushReadinessLabel(unauthorized)).toBe(
      "Admin authentication required",
    );
  });

  it("maps typed readiness states to admin-safe UI labels", () => {
    expect(
      pushReadinessLabel({
        configured: true,
        status: "READY",
        reason: "",
        setupHint: "",
      }),
    ).toBe("Ready");
    expect(
      pushReadinessLabel({
        configured: false,
        status: "SERVER_CONFIG_MISSING",
        reason: "",
        setupHint: "",
      }),
    ).toBe("Firebase server configuration missing");
    expect(
      pushReadinessLabel({
        configured: false,
        status: "FUNCTION_MISSING",
        reason: "",
        setupHint: "",
      }),
    ).toBe("Push sender unavailable");
    expect(
      pushReadinessLabel({
        configured: false,
        status: "SCHEMA_MISSING",
        reason: "",
        setupHint: "",
      }),
    ).toBe("Notification schema missing");
    expect(
      pushReadinessLabel({
        configured: false,
        status: "UNKNOWN",
        reason: "",
        setupHint: "",
      }),
    ).toBe("Unable to check push status");
  });

  it("counts selected active Android devices", () => {
    expect(
      selectedActiveAndroidDeviceCount(
        [
          {
            id: "user-a",
            label: "User A",
            email: null,
            activeAndroidDeviceCount: 1,
          },
          {
            id: "user-b",
            label: "User B",
            email: null,
            activeAndroidDeviceCount: 2,
          },
        ],
        ["user-a", "user-b"],
      ),
    ).toBe(3);
  });

  it("keeps All users push disabled even when readiness is ready", () => {
    expect(
      canEnablePushChannel({
        audienceType: "all_users",
        pushConfiguration: pushConfigured,
        selectedUsers: [
          {
            id: "user-a",
            label: "User A",
            email: null,
            activeAndroidDeviceCount: 1,
          },
        ],
        selectedUserIds: ["user-a"],
      }),
    ).toBe(false);
  });

  it("enables push for an explicitly selected user with an active Android device", () => {
    expect(
      canEnablePushChannel({
        audienceType: "selected_candidates",
        pushConfiguration: pushConfigured,
        selectedUsers: [
          {
            id: "user-a",
            label: "User A",
            email: null,
            activeAndroidDeviceCount: 1,
          },
        ],
        selectedUserIds: ["user-a"],
      }),
    ).toBe(true);
  });

  it("keeps selected-user push disabled when no active Android device exists", () => {
    expect(
      canEnablePushChannel({
        audienceType: "selected_candidates",
        pushConfiguration: pushConfigured,
        selectedUsers: [
          {
            id: "user-a",
            label: "User A",
            email: null,
            activeAndroidDeviceCount: 0,
          },
        ],
        selectedUserIds: ["user-a"],
      }),
    ).toBe(false);
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

  it("forwards the admin JWT with Supabase apikey for push readiness", () => {
    const source = readFileSync(
      "src/features/admin/notifications/server.ts",
      "utf8",
    );

    expect(source).toContain("apikey: anonKey");
    expect(source).toContain("authorization: `Bearer ${session.access_token}`");
    expect(source).not.toContain("authorization: `Bearer ${anonKey}`");
  });

  it("keeps Edge Function health mode typed and secret-safe", () => {
    const source = readFileSync(
      "../supabase/functions/send-push-notification/index.ts",
      "utf8",
    );

    expect(source).toContain("health_check");
    expect(source).toContain('status: "READY"');
    expect(source).toContain('status: "UNAUTHORIZED"');
    expect(source).toContain('status: "SERVER_CONFIG_MISSING"');
    expect(source).toContain("accepted_count");
    expect(source).not.toContain("results.push({ device_id");
  });
});
