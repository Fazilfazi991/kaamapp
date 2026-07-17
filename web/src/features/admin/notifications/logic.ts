import type {
  AdminNotificationActionState,
  AudienceType,
  DeliveryChannel,
  PushConfiguration,
  SelectableUser,
} from "./types";

export const supportedNonPushChannels = new Set<DeliveryChannel>(["in_app"]);

export const unavailablePushMessage =
  "Push notifications are not configured yet. You can still send an in-app notification.";

export function pushReadinessLabel(pushConfiguration: PushConfiguration) {
  switch (pushConfiguration.status) {
    case "READY":
      return "Ready";
    case "UNAUTHORIZED":
      return "Admin authentication required";
    case "FUNCTION_MISSING":
      return "Push sender unavailable";
    case "SERVER_CONFIG_MISSING":
      return "Firebase server configuration missing";
    case "SCHEMA_MISSING":
      return "Notification schema missing";
    case "UNREACHABLE":
    case "UNKNOWN":
      return "Unable to check push status";
  }
}

export function audienceSupportsPush(audienceType: AudienceType) {
  return (
    audienceType === "selected_candidates" ||
    audienceType === "selected_employers"
  );
}

export function selectedActiveAndroidDeviceCount(
  users: SelectableUser[],
  selectedUserIds: string[],
) {
  const selected = new Set(selectedUserIds);
  return users
    .filter((user) => selected.has(user.id))
    .reduce((total, user) => total + user.activeAndroidDeviceCount, 0);
}

export function canEnablePushChannel({
  audienceType,
  pushConfiguration,
  selectedUsers,
  selectedUserIds,
}: {
  audienceType: AudienceType;
  pushConfiguration: PushConfiguration;
  selectedUsers: SelectableUser[];
  selectedUserIds: string[];
}) {
  return (
    pushConfiguration.configured &&
    audienceSupportsPush(audienceType) &&
    selectedUserIds.length > 0 &&
    selectedActiveAndroidDeviceCount(selectedUsers, selectedUserIds) > 0
  );
}

export function normalizeChannels(
  channels: DeliveryChannel[],
  pushConfiguration: PushConfiguration,
):
  | { ok: true; channels: DeliveryChannel[]; warning?: string }
  | { ok: false; state: AdminNotificationActionState } {
  const unique = [...new Set(channels)];
  if (unique.length === 0) {
    return {
      ok: false,
      state: failure(
        "NO_CHANNEL_SELECTED",
        "Select at least one notification channel.",
      ),
    };
  }

  const withoutUnavailablePush = pushConfiguration.configured
    ? unique
    : unique.filter((channel) => channel !== "push");
  if (withoutUnavailablePush.length === 0) {
    return {
      ok: false,
      state: failure("PUSH_NOT_CONFIGURED", unavailablePushMessage),
    };
  }

  const supportedChannels = pushConfiguration.configured
    ? new Set<DeliveryChannel>(["in_app", "push"])
    : supportedNonPushChannels;
  const unsupported = withoutUnavailablePush.filter(
    (channel) => !supportedChannels.has(channel),
  );
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
    warning:
      !pushConfiguration.configured && unique.includes("push")
        ? unavailablePushMessage
        : undefined,
  };
}

function failure(code: string, message: string): AdminNotificationActionState {
  return { ok: false, code, message };
}
