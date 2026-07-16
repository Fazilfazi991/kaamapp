import type { AdminNotificationActionState, DeliveryChannel, PushConfiguration } from "./types";

export const supportedNonPushChannels = new Set<DeliveryChannel>(["in_app"]);

export const unavailablePushMessage =
  "Push notifications are not configured yet. You can still send an in-app notification.";

export function normalizeChannels(channels: DeliveryChannel[], pushConfiguration: PushConfiguration):
  | { ok: true; channels: DeliveryChannel[]; warning?: string }
  | { ok: false; state: AdminNotificationActionState } {
  const unique = [...new Set(channels)];
  if (unique.length === 0) {
    return { ok: false, state: failure("NO_CHANNEL_SELECTED", "Select at least one notification channel.") };
  }

  const withoutUnavailablePush = pushConfiguration.configured ? unique : unique.filter((channel) => channel !== "push");
  if (withoutUnavailablePush.length === 0) {
    return { ok: false, state: failure("PUSH_NOT_CONFIGURED", unavailablePushMessage) };
  }

  const supportedChannels = pushConfiguration.configured
    ? new Set<DeliveryChannel>(["in_app", "push"])
    : supportedNonPushChannels;
  const unsupported = withoutUnavailablePush.filter((channel) => !supportedChannels.has(channel));
  if (unsupported.length > 0) {
    return {
      ok: false,
      state: failure(
        "CHANNEL_NOT_CONFIGURED",
        "Email and WhatsApp delivery are not configured yet. Use in-app notification only.",
      ),
    };
  }

  return {
    ok: true,
    channels: withoutUnavailablePush,
    warning: !pushConfiguration.configured && unique.includes("push") ? unavailablePushMessage : undefined,
  };
}

function failure(code: string, message: string): AdminNotificationActionState {
  return { ok: false, code, message };
}
