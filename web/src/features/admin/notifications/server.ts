"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/features/admin/auth/require-admin";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireSupabaseConfig } from "@/lib/supabase/env";
import {
  actionOptions,
  audienceOptions,
  type AudienceCounts,
  type AudienceType,
  type DeliveryChannel,
  initialAdminNotificationActionState,
  type AdminNotificationActionState,
  type AdminNotificationActionType,
  type AdminNotificationRow,
  type AdminNotificationStatus,
  type AdminNotificationType,
  notificationTypeOptions,
  type PushConfiguration,
  type SelectableUser,
  type PushReadinessStatus,
} from "./types";
import { normalizeChannels } from "./logic";

export async function loadAdminNotificationPageData({
  q,
  status,
  audience,
  type,
}: {
  q?: string;
  status?: string;
  audience?: string;
  type?: string;
}) {
  await requireAdmin();
  const [counts, candidates, employers, history, pushConfiguration] =
    await Promise.all([
      loadAudienceCounts(),
      loadSelectableUsers("candidate"),
      loadSelectableUsers("employer"),
      loadNotificationHistory({ q, status, audience, type }),
      loadPushConfiguration(),
    ]);

  return {
    counts,
    candidates,
    employers,
    history,
    pushConfiguration,
  };
}

export async function createAdminNotificationAction(
  previousState: AdminNotificationActionState = initialAdminNotificationActionState,
  formData: FormData,
): Promise<AdminNotificationActionState> {
  void previousState;
  const admin = await requireAdmin();
  const supabase = await createServerSupabaseClient();
  const parsed = parseNotificationForm(formData);
  if (!parsed.ok) return failure(parsed.code, parsed.message);
  const pushConfiguration = await loadPushConfiguration();
  const normalizedChannels = normalizeChannels(
    parsed.channels,
    pushConfiguration,
  );
  if (!normalizedChannels.ok) return normalizedChannels.state;

  const resolvedRecipientIds =
    parsed.mode === "test" && parsed.selectedUserIds.length === 0
      ? [admin.userId]
      : await resolveRecipientIds(parsed.audienceType, parsed.selectedUserIds);
  const recipientIds =
    await filterDeliverableRecipientIds(resolvedRecipientIds);
  if (recipientIds.length === 0 && parsed.mode !== "draft") {
    return failure(
      "NO_ELIGIBLE_RECIPIENTS",
      "No recipients match this audience.",
    );
  }

  const safeWarning = normalizedChannels.warning;

  const sendNow = parsed.mode !== "draft" && parsed.scheduleMode === "now";
  const status: AdminNotificationStatus =
    parsed.mode === "draft"
      ? "draft"
      : parsed.scheduleMode === "later"
        ? "scheduled"
        : "sent";
  const inAppRecipientCount =
    normalizedChannels.channels.includes("in_app") && parsed.mode !== "draft"
      ? recipientIds.length
      : 0;
  const idempotencyKey =
    parsed.idempotencyKey ??
    `${admin.userId}:${parsed.mode}:${parsed.title}:${parsed.message}:${parsed.audienceType}:${parsed.scheduleMode}:${parsed.scheduledAt ?? ""}`;

  const { data: existingNotification, error: existingError } = await supabase
    .from("admin_notifications")
    .select("id,status,recipient_count")
    .eq("created_by", admin.userId)
    .eq("idempotency_key", idempotencyKey)
    .maybeSingle<{
      id: string;
      status: AdminNotificationStatus;
      recipient_count: number | null;
    }>();

  if (existingError && !isAdminNotificationSchemaMissing(existingError)) {
    return failure(
      "BROADCAST_CREATE_FAILED",
      "Could not verify notification submission state. Please try again.",
    );
  }

  if (existingNotification) {
    revalidatePath("/admin/notifications");
    return success(
      "Notification already submitted. History has been refreshed.",
      existingNotification.id,
      {
        inAppRecipientCount: existingNotification.recipient_count ?? 0,
        scheduled: existingNotification.status === "scheduled",
        idempotencyKey,
        warning: safeWarning,
      },
    );
  }

  const { data: notification, error } = await supabase
    .from("admin_notifications")
    .insert({
      title: parsed.title,
      message: parsed.message,
      notification_type: parsed.notificationType,
      audience_type: parsed.audienceType,
      audience_filters: {
        selected_user_ids: parsed.selectedUserIds,
        mode: parsed.mode,
      },
      action_type: parsed.actionType,
      action_value: parsed.actionValue,
      channels: normalizedChannels.channels,
      status,
      recipient_count:
        parsed.mode === "draft" ? recipientIds.length : recipientIds.length,
      in_app_success_count: 0,
      push_success_count: 0,
      push_failure_count: 0,
      failure_summary: safeWarning ?? null,
      idempotency_key: idempotencyKey,
      scheduled_at: parsed.scheduleMode === "later" ? parsed.scheduledAt : null,
      sent_at: sendNow ? new Date().toISOString() : null,
      created_by: admin.userId,
      sent_by: sendNow ? admin.userId : null,
    })
    .select("id")
    .maybeSingle<{ id: string }>();

  if (error || !notification) {
    if (isAdminNotificationSchemaMissing(error)) {
      return failure(
        "BROADCAST_TABLE_MISSING",
        "Admin notification tables are not applied in Supabase yet. Apply supabase/013_admin_notifications.sql first.",
      );
    }
    return failure(
      "BROADCAST_CREATE_FAILED",
      "Could not save notification. Please try again.",
    );
  }

  if (parsed.mode !== "draft") {
    const recipientRows = recipientIds.map((userId) => ({
      notification_id: notification.id,
      user_id: userId,
      in_app_status:
        normalizedChannels.channels.includes("in_app") && sendNow
          ? "pending"
          : "skipped",
      push_status: normalizedChannels.channels.includes("push")
        ? "pending"
        : "skipped",
      email_status: normalizedChannels.channels.includes("email")
        ? "pending"
        : "skipped",
      whatsapp_status: normalizedChannels.channels.includes("whatsapp")
        ? "pending"
        : "skipped",
      delivered_at: null,
    }));

    if (recipientRows.length > 0) {
      const batchSize = 500;
      for (let index = 0; index < recipientRows.length; index += batchSize) {
        const { error: recipientError } = await supabase
          .from("admin_notification_recipients")
          .insert(recipientRows.slice(index, index + batchSize));
        if (recipientError) {
          await supabase
            .from("admin_notifications")
            .update({ status: "partially_sent" })
            .eq("id", notification.id);
          return {
            ok: false,
            code: "PARTIAL_CHANNEL_FAILURE",
            message:
              "Notification was saved, but some recipient records could not be created.",
            broadcastId: notification.id,
            inAppRecipientCount,
            pushEligibleDeviceCount: 0,
            warning:
              "Some recipient records failed. No raw backend error was exposed.",
            idempotencyKey,
          };
        }
      }
    }
  }

  const delivery =
    sendNow && parsed.mode !== "draft"
      ? await deliverAdminNotification({
          supabase,
          broadcastId: notification.id,
          adminUserId: admin.userId,
          recipientIds,
          title: parsed.title,
          message: parsed.message,
          notificationType: parsed.notificationType,
          actionRoute: safeActionRoute(parsed.actionType, parsed.actionValue),
          channels: normalizedChannels.channels,
        })
      : {
          inAppSuccessCount: 0,
          pushEligibleDeviceCount: 0,
          pushSuccessCount: 0,
          pushFailureCount: 0,
          failureSummary: null as string | null,
        };

  revalidatePath("/admin/notifications");
  if (parsed.mode === "draft") {
    return success("Draft saved.", notification.id, {
      idempotencyKey,
      warning: safeWarning,
    });
  }
  if (parsed.mode === "test") {
    if (
      normalizedChannels.channels.includes("in_app") &&
      delivery.inAppSuccessCount === 0
    ) {
      return {
        ok: false,
        code: "RECIPIENT_NOTIFICATION_CREATE_FAILED",
        message:
          delivery.failureSummary ??
          "Could not create recipient notification records.",
        broadcastId: notification.id,
        inAppRecipientCount: 0,
        pushEligibleDeviceCount: delivery.pushEligibleDeviceCount,
        warning: delivery.failureSummary ?? safeWarning,
        idempotencyKey,
      };
    }
    return success(
      "Test notification sent to your admin account.",
      notification.id,
      {
        inAppRecipientCount: delivery.inAppSuccessCount,
        pushEligibleDeviceCount: delivery.pushEligibleDeviceCount,
        idempotencyKey,
        warning: delivery.failureSummary ?? safeWarning,
      },
    );
  }
  if (status === "scheduled") {
    return success("Notification scheduled.", notification.id, {
      inAppRecipientCount,
      scheduled: true,
      idempotencyKey,
      warning: safeWarning,
    });
  }
  if (
    normalizedChannels.channels.includes("in_app") &&
    delivery.inAppSuccessCount === 0
  ) {
    return {
      ok: false,
      code: "RECIPIENT_NOTIFICATION_CREATE_FAILED",
      message:
        delivery.failureSummary ??
        "Could not create recipient notification records.",
      broadcastId: notification.id,
      inAppRecipientCount: 0,
      pushEligibleDeviceCount: delivery.pushEligibleDeviceCount,
      warning: delivery.failureSummary ?? safeWarning,
      idempotencyKey,
    };
  }
  return success(
    normalizedChannels.channels.includes("push")
      ? "Notification sent."
      : "In-app notification sent.",
    notification.id,
    {
      inAppRecipientCount: delivery.inAppSuccessCount,
      pushEligibleDeviceCount: delivery.pushEligibleDeviceCount,
      idempotencyKey,
      warning: delivery.failureSummary ?? safeWarning,
    },
  );
}

export async function loadAudienceCounts(): Promise<AudienceCounts> {
  await requireAdmin();
  const entries = await Promise.all(
    audienceOptions.map(
      async (option) =>
        [option.value, await countAudience(option.value)] as const,
    ),
  );
  return Object.fromEntries(entries) as AudienceCounts;

  async function countAudience(audienceType: AudienceType) {
    const ids = await resolveRecipientIds(audienceType, []);
    return ids.length;
  }
}

async function loadSelectableUsers(
  role: "candidate" | "employer",
): Promise<SelectableUser[]> {
  const supabase = await createServerSupabaseClient();
  const [{ data, error }, { data: deviceRows }] = await Promise.all([
    supabase
      .from("profiles")
      .select("id,full_name,email")
      .eq("role", role)
      .neq("status", "blocked")
      .order("created_at", { ascending: false })
      .limit(100),
    supabase
      .from("admin_push_device_status")
      .select("user_id,id")
      .eq("platform", "android")
      .eq("is_active", true),
  ]);
  if (error) return [];
  const activeDeviceCounts = new Map<string, number>();
  for (const row of deviceRows ?? []) {
    const userId = row.user_id as string;
    activeDeviceCounts.set(userId, (activeDeviceCounts.get(userId) ?? 0) + 1);
  }
  return (data ?? []).map((row) => ({
    id: row.id as string,
    label: String(row.full_name || row.email || row.id),
    email: (row.email as string | null) ?? null,
    activeAndroidDeviceCount: activeDeviceCounts.get(row.id as string) ?? 0,
  }));
}

async function loadNotificationHistory({
  q,
  status,
  audience,
  type,
}: {
  q?: string;
  status?: string;
  audience?: string;
  type?: string;
}) {
  const supabase = await createServerSupabaseClient();
  let query = supabase
    .from("admin_notifications")
    .select(
      "id,title,message,notification_type,audience_type,audience_filters,action_type,action_value,channels,status,recipient_count,in_app_success_count,push_eligible_device_count,push_success_count,push_failure_count,push_skipped_count,failure_summary,idempotency_key,scheduled_at,sent_at,created_by,sent_by,created_at,profiles:created_by(email,full_name)",
    )
    .order("created_at", { ascending: false })
    .limit(25);

  if (status) query = query.eq("status", status);
  if (audience) query = query.eq("audience_type", audience);
  if (type) query = query.eq("notification_type", type);
  if (q)
    query = query.or(
      `title.ilike.%${escapeLike(q)}%,message.ilike.%${escapeLike(q)}%`,
    );

  const { data, error } = await query;
  if (error) {
    if (isAdminNotificationSchemaMissing(error)) return [];
    throw error;
  }
  return (data ?? []) as unknown as AdminNotificationRow[];
}

async function resolveRecipientIds(
  audienceType: AudienceType,
  selectedUserIds: string[],
) {
  const supabase = await createServerSupabaseClient();

  if (
    audienceType === "selected_candidates" ||
    audienceType === "selected_employers"
  ) {
    return [...new Set(selectedUserIds.filter(Boolean))];
  }

  if (
    audienceType === "pending_documents" ||
    audienceType === "rejected_documents"
  ) {
    const statuses =
      audienceType === "pending_documents"
        ? ["pending", "pending_review", "pending_verification"]
        : ["rejected", "resubmission_requested"];
    const [{ data: candidateDocs }, { data: employerDocs }] = await Promise.all(
      [
        supabase
          .from("candidate_document_versions")
          .select("candidate_id")
          .in("status", statuses)
          .limit(5000),
        supabase
          .from("verification_documents")
          .select("owner_id")
          .in("status", statuses)
          .limit(5000),
      ],
    );
    return uniqueIds([
      ...(candidateDocs ?? []).map((row) => row.candidate_id as string | null),
      ...(employerDocs ?? []).map((row) => row.owner_id as string | null),
    ]);
  }

  if (
    audienceType === "paid_candidates" ||
    audienceType === "unpaid_candidates"
  ) {
    const { data: memberships } = await supabase
      .from("candidate_memberships")
      .select("candidate_id,status,expires_at")
      .limit(5000);
    const paid = new Set(
      (memberships ?? [])
        .filter(
          (row) =>
            row.status === "active" &&
            (!row.expires_at ||
              new Date(row.expires_at as string) > new Date()),
        )
        .map((row) => row.candidate_id as string),
    );
    if (audienceType === "paid_candidates") return [...paid];
    const candidateIds = await profileIdsByRole("candidate");
    return candidateIds.filter((id) => !paid.has(id));
  }

  if (audienceType === "matched_users") {
    const { data } = await supabase
      .from("matches")
      .select("candidate_id,employer_id")
      .limit(5000);
    return uniqueIds(
      (data ?? []).flatMap((row) => [
        row.candidate_id as string | null,
        row.employer_id as string | null,
      ]),
    );
  }

  if (audienceType === "inactive_users") {
    const { data } = await supabase
      .from("profiles")
      .select("id")
      .in("role", ["candidate", "employer"])
      .neq("status", "active")
      .limit(5000);
    return uniqueIds((data ?? []).map((row) => row.id as string | null));
  }

  if (audienceType === "all_candidates") return profileIdsByRole("candidate");
  if (audienceType === "all_employers") return profileIdsByRole("employer");
  return profileIdsByRole(["candidate", "employer"]);

  async function profileIdsByRole(
    role: "candidate" | "employer" | Array<"candidate" | "employer">,
  ) {
    let query = supabase
      .from("profiles")
      .select("id")
      .neq("status", "blocked")
      .limit(5000);
    query = Array.isArray(role)
      ? query.in("role", role)
      : query.eq("role", role);
    const { data } = await query;
    return uniqueIds((data ?? []).map((row) => row.id as string | null));
  }
}

function parseNotificationForm(formData: FormData) {
  const mode = String(formData.get("mode") ?? "draft") as
    "draft" | "test" | "send";
  const title = String(formData.get("title") ?? "").trim();
  const message = String(formData.get("message") ?? "").trim();
  const audienceType = String(
    formData.get("audienceType") ?? "all_users",
  ) as AudienceType;
  const notificationType = String(
    formData.get("notificationType") ?? "general_announcement",
  ) as AdminNotificationType;
  const channels = formData.getAll("channels").map(String) as DeliveryChannel[];
  const actionType = String(
    formData.get("actionType") ?? "none",
  ) as AdminNotificationActionType;
  const actionValue = String(formData.get("actionValue") ?? "").trim() || null;
  const scheduleMode = String(formData.get("scheduleMode") ?? "now") as
    "now" | "later";
  const scheduledAt = String(formData.get("scheduledAt") ?? "").trim() || null;
  const selectedUserIds = formData.getAll("selectedUserIds").map(String);
  const idempotencyKey =
    String(formData.get("idempotencyKey") ?? "").trim() || null;

  if (!["draft", "test", "send"].includes(mode))
    return fail("INVALID_ACTION", "Invalid action.");
  if (title.length === 0 || title.length > 140)
    return fail("INVALID_TITLE", "Title must be 1-140 characters.");
  if (message.length === 0 || message.length > 1200)
    return fail("INVALID_MESSAGE", "Message must be 1-1200 characters.");
  if (!audienceOptions.some((option) => option.value === audienceType))
    return fail("INVALID_AUDIENCE", "Select a valid audience.");
  if (
    !notificationTypeOptions.some((option) => option.value === notificationType)
  )
    return fail("INVALID_TYPE", "Select a valid notification type.");
  if (channels.length === 0)
    return fail(
      "NO_CHANNEL_SELECTED",
      "Select at least one notification channel.",
    );
  if (
    !channels.every((channel) =>
      ["in_app", "push", "email", "whatsapp"].includes(channel),
    )
  ) {
    return fail("INVALID_CHANNEL", "Select valid delivery channels.");
  }
  if (
    channels.includes("push") &&
    audienceType !== "selected_candidates" &&
    audienceType !== "selected_employers"
  ) {
    return fail(
      "PUSH_REQUIRES_SELECTED_USERS",
      "Push notifications must target selected QA users only.",
    );
  }
  if (
    channels.includes("push") &&
    selectedUserIds.filter(Boolean).length === 0
  ) {
    return fail(
      "PUSH_REQUIRES_SELECTED_USERS",
      "Select one QA user before enabling push.",
    );
  }
  if (!actionOptions.some((option) => option.value === actionType))
    return fail("INVALID_ACTION_LINK", "Select a valid action link.");
  if (
    actionValue &&
    (!actionValue.startsWith("/") ||
      actionValue.startsWith("//") ||
      actionValue.includes("://"))
  ) {
    return fail(
      "INVALID_ACTION_LINK",
      "Action links must be internal KAAM routes.",
    );
  }
  if (scheduleMode === "later" && !scheduledAt)
    return fail("INVALID_SCHEDULE", "Select a scheduled date and time.");
  if (
    scheduleMode === "later" &&
    scheduledAt &&
    new Date(scheduledAt).getTime() <= Date.now()
  ) {
    return fail("INVALID_SCHEDULE", "Choose a future scheduled date and time.");
  }

  return {
    ok: true as const,
    mode,
    title,
    message,
    audienceType,
    notificationType,
    channels,
    actionType,
    actionValue,
    scheduleMode,
    scheduledAt,
    selectedUserIds,
    idempotencyKey,
  };
}

function fail(code: string, message: string) {
  return { ok: false as const, code, message };
}

async function filterDeliverableRecipientIds(recipientIds: string[]) {
  const unique = uniqueIds(recipientIds);
  if (unique.length === 0) return [];
  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("profiles")
    .select("id,status")
    .in("id", unique);
  const allowed = new Set(
    (data ?? [])
      .filter((row) => row.status !== "blocked")
      .map((row) => row.id as string),
  );
  return unique.filter((id) => allowed.has(id));
}

async function deliverAdminNotification({
  supabase,
  broadcastId,
  adminUserId,
  recipientIds,
  title,
  message,
  notificationType,
  actionRoute,
  channels,
}: {
  supabase: Awaited<ReturnType<typeof createServerSupabaseClient>>;
  broadcastId: string;
  adminUserId: string;
  recipientIds: string[];
  title: string;
  message: string;
  notificationType: AdminNotificationType;
  actionRoute: string | null;
  channels: DeliveryChannel[];
}) {
  const shouldCreateInAppRecord =
    channels.includes("in_app") || channels.includes("push");
  const shouldPush = channels.includes("push");
  let inAppSuccessCount = 0;
  let pushEligibleDeviceCount = 0;
  let pushSuccessCount = 0;
  let pushFailureCount = 0;
  let skippedPushCount = 0;
  let failureSummary: string | null = null;

  if (!shouldCreateInAppRecord || recipientIds.length === 0) {
    return {
      inAppSuccessCount,
      pushEligibleDeviceCount,
      pushSuccessCount,
      pushFailureCount,
      failureSummary,
    };
  }

  const notificationRows = recipientIds.map((recipientId) => ({
    recipient_id: recipientId,
    type: "admin_broadcast",
    title,
    body: message,
    action_route: actionRoute,
    data: {
      admin_notification_id: broadcastId,
      admin_notification_type: notificationType,
    },
    dedupe_key: `admin:${broadcastId}:${recipientId}`,
    source_type: "admin_notification",
    source_id: broadcastId,
    created_by: adminUserId,
  }));

  const { data: insertedNotifications, error: insertError } = await supabase
    .from("notifications")
    .insert(notificationRows)
    .select("id,recipient_id");

  if (insertError) {
    const safeError = safeDatabaseError(
      insertError,
      "Could not create recipient notification records.",
    );
    await supabase
      .from("admin_notifications")
      .update({
        status: "failed",
        failure_summary: safeError,
      })
      .eq("id", broadcastId);
    return {
      inAppSuccessCount,
      pushEligibleDeviceCount,
      pushSuccessCount,
      pushFailureCount: shouldPush ? recipientIds.length : 0,
      failureSummary: safeError,
    };
  }

  const inserted = (insertedNotifications ?? []) as Array<{
    id: string;
    recipient_id: string;
  }>;
  inAppSuccessCount = inserted.length;

  if (inserted.length > 0) {
    await supabase
      .from("admin_notification_recipients")
      .update({
        in_app_status: channels.includes("in_app") ? "sent" : "skipped",
        delivered_at: new Date().toISOString(),
      })
      .eq("notification_id", broadcastId)
      .in(
        "user_id",
        inserted.map((row) => row.recipient_id),
      );
  }

  if (shouldPush) {
    const { count } = await supabase
      .from("admin_push_device_status")
      .select("id", { count: "exact", head: true })
      .in("user_id", recipientIds)
      .eq("platform", "android")
      .eq("is_active", true);
    pushEligibleDeviceCount = count ?? 0;

    if (pushEligibleDeviceCount === 0) {
      skippedPushCount = inserted.length;
      await supabase
        .from("admin_notification_recipients")
        .update({
          push_status: "skipped",
          error_message: "No registered Android device",
        })
        .eq("notification_id", broadcastId)
        .in(
          "user_id",
          inserted.map((row) => row.recipient_id),
        );
      failureSummary = "No registered Android device";
    } else {
      for (const row of inserted) {
        const { data, error } = await supabase.functions.invoke(
          "send-push-notification",
          {
            body: { notification_id: row.id },
          },
        );
        const status = String(
          (data as { status?: unknown } | null)?.status ?? "",
        );
        const pushStatus =
          !error && status === "sent"
            ? "sent"
            : status === "skipped"
              ? "skipped"
              : "failed";
        if (pushStatus === "sent") pushSuccessCount += 1;
        if (pushStatus === "skipped") skippedPushCount += 1;
        if (pushStatus === "failed") pushFailureCount += 1;

        await supabase
          .from("admin_notification_recipients")
          .update({
            push_status: pushStatus,
            error_message:
              pushStatus === "failed"
                ? "Push delivery failed. Check Edge Function logs."
                : null,
          })
          .eq("notification_id", broadcastId)
          .eq("user_id", row.recipient_id);
      }
    }
  }

  if (pushFailureCount > 0) {
    failureSummary = `${pushFailureCount} push notification${pushFailureCount === 1 ? "" : "s"} failed.`;
  } else if (skippedPushCount > 0) {
    failureSummary = `${skippedPushCount} push notification${skippedPushCount === 1 ? "" : "s"} skipped by preferences, blocked status, or missing active Android devices.`;
  }

  const finalStatus: AdminNotificationStatus =
    shouldPush && pushEligibleDeviceCount === 0
      ? "no_eligible_devices"
      : pushFailureCount > 0 && (inAppSuccessCount > 0 || pushSuccessCount > 0)
        ? "partially_sent"
        : pushFailureCount > 0
          ? "failed"
          : "sent";
  await supabase
    .from("admin_notifications")
    .update({
      status: finalStatus,
      in_app_success_count: inAppSuccessCount,
      push_eligible_device_count: pushEligibleDeviceCount,
      push_success_count: pushSuccessCount,
      push_failure_count: pushFailureCount,
      push_skipped_count: skippedPushCount,
      failure_summary: failureSummary,
      sent_at: new Date().toISOString(),
    })
    .eq("id", broadcastId);

  return {
    inAppSuccessCount,
    pushEligibleDeviceCount,
    pushSuccessCount,
    pushFailureCount,
    failureSummary,
  };
}

function safeActionRoute(
  actionType: AdminNotificationActionType,
  actionValue: string | null,
) {
  if (actionType === "none") return null;
  if (!actionValue) return null;
  return actionValue;
}

export async function loadPushConfiguration(): Promise<PushConfiguration> {
  await requireAdmin();
  const supabase = await createServerSupabaseClient();
  try {
    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (!session?.access_token) {
      return pushConfiguration(
        "UNAUTHORIZED",
        "Admin push health check is unauthorized.",
        "Sign in again as an admin user.",
      );
    }
    const { url, anonKey } = requireSupabaseConfig();
    const response = await fetch(`${url}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        apikey: anonKey,
        authorization: `Bearer ${session.access_token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ health_check: true }),
    });
    if (response.status === 401 || response.status === 403) {
      return pushConfiguration(
        "UNAUTHORIZED",
        "Admin push health check is unauthorized.",
        "Sign in again as an admin user.",
        response.status,
      );
    }
    if (response.status === 404) {
      return pushConfiguration(
        "FUNCTION_MISSING",
        "Push health check is unavailable.",
        "Deploy the send-push-notification Edge Function.",
        response.status,
      );
    }
    if (!response.ok) {
      return pushConfiguration(
        "UNREACHABLE",
        "Push health check could not be reached.",
        "Check the Edge Function deployment.",
        response.status,
      );
    }
    const data = await response.json().catch(() => null);
    const status = parsePushReadinessStatus(
      (data as { status?: unknown } | null)?.status,
    );
    const safeReason =
      typeof (data as { reason?: unknown } | null)?.reason === "string"
        ? String((data as { reason?: unknown }).reason)
        : null;
    if (status === "READY") {
      return {
        configured: true,
        status,
        reason: "",
        setupHint: "Android FCM push is configured for selected QA users.",
      };
    }
    if (status === "SERVER_CONFIG_MISSING") {
      return pushConfiguration(
        status,
        safeReason ?? "Push server configuration is incomplete.",
        "Confirm the Edge Function secret is set.",
        response.status,
      );
    }
    if (status === "SCHEMA_MISSING") {
      return pushConfiguration(
        status,
        safeReason ?? "Notification schema is not fully available.",
        "Apply the notification migrations.",
        response.status,
      );
    }
    if (status === "UNAUTHORIZED") {
      return pushConfiguration(
        status,
        "Admin push health check is unauthorized.",
        "Sign in again as an admin user.",
        response.status,
      );
    }
    return pushConfiguration(
      status,
      safeReason ?? "Push health check did not report ready.",
      "Check Edge Function logs.",
      response.status,
    );
  } catch {
    return pushConfiguration(
      "UNREACHABLE",
      "Push health check could not be reached.",
      "Check the Edge Function deployment.",
    );
  }
}

function pushConfiguration(
  status: PushReadinessStatus,
  reason: string,
  setupHint: string,
  httpStatus?: number,
): PushConfiguration {
  return {
    configured: false,
    status,
    reason,
    setupHint,
    httpStatus,
  };
}

function parsePushReadinessStatus(value: unknown): PushReadinessStatus {
  return [
    "READY",
    "FUNCTION_MISSING",
    "SERVER_CONFIG_MISSING",
    "SCHEMA_MISSING",
    "UNREACHABLE",
    "UNAUTHORIZED",
    "UNKNOWN",
  ].includes(String(value))
    ? (String(value) as PushReadinessStatus)
    : "UNKNOWN";
}

function failure(code: string, message: string): AdminNotificationActionState {
  return { ok: false, code, message };
}

function success(
  message: string,
  broadcastId: string,
  options: {
    inAppRecipientCount?: number;
    pushEligibleDeviceCount?: number;
    scheduled?: boolean;
    warning?: string;
    idempotencyKey?: string;
  } = {},
): AdminNotificationActionState {
  return {
    ok: true,
    code: "SUCCESS",
    message: options.warning ? `${message} ${options.warning}` : message,
    broadcastId,
    inAppRecipientCount: options.inAppRecipientCount ?? 0,
    pushEligibleDeviceCount: options.pushEligibleDeviceCount ?? 0,
    scheduled: options.scheduled ?? false,
    warning: options.warning,
    idempotencyKey: options.idempotencyKey,
  };
}

function uniqueIds(values: Array<string | null | undefined>) {
  return [
    ...new Set(values.filter((value): value is string => Boolean(value))),
  ];
}

function escapeLike(value: string) {
  return value.replace(/[%_]/g, (match) => `\\${match}`);
}

function safeDatabaseError(error: unknown, fallback: string) {
  if (!error || typeof error !== "object") return fallback;
  const maybeError = error as {
    code?: string;
    message?: string;
    details?: string;
  };
  const code = maybeError.code ? ` (${maybeError.code})` : "";
  const message = maybeError.message?.trim();
  if (!message) return fallback;
  return `${fallback}${code}: ${message}`;
}

function isAdminNotificationSchemaMissing(error: unknown) {
  if (!error || typeof error !== "object") return false;
  const maybeError = error as { code?: string; message?: string };
  const message = maybeError.message?.toLowerCase() ?? "";
  return (
    maybeError.code === "42P01" ||
    maybeError.code === "PGRST205" ||
    (message.includes("admin_notifications") &&
      message.includes("schema cache")) ||
    (message.includes("admin_notification_recipients") &&
      message.includes("schema cache"))
  );
}
