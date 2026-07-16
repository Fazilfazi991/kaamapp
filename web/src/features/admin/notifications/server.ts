"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/features/admin/auth/require-admin";
import { createServerSupabaseClient } from "@/lib/supabase/server";
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
} from "./types";
import { normalizeChannels, unavailablePushMessage } from "./logic";

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
  const [counts, candidates, employers, history, pushConfiguration] = await Promise.all([
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
  const normalizedChannels = normalizeChannels(parsed.channels, pushConfiguration);
  if (!normalizedChannels.ok) return normalizedChannels.state;

  const recipientIds =
    parsed.mode === "test" ? [admin.userId] : await resolveRecipientIds(parsed.audienceType, parsed.selectedUserIds);
  if (recipientIds.length === 0 && parsed.mode !== "draft") {
    return failure("NO_ELIGIBLE_RECIPIENTS", "No recipients match this audience.");
  }

  const safeWarning = normalizedChannels.warning;

  const sendNow = parsed.mode !== "draft" && parsed.scheduleMode === "now";
  const status: AdminNotificationStatus =
    parsed.mode === "draft" ? "draft" : parsed.scheduleMode === "later" ? "scheduled" : "sent";
  const inAppRecipientCount = normalizedChannels.channels.includes("in_app") && parsed.mode !== "draft" ? recipientIds.length : 0;
  const idempotencyKey =
    parsed.idempotencyKey ??
    `${admin.userId}:${parsed.mode}:${parsed.title}:${parsed.message}:${parsed.audienceType}:${parsed.scheduleMode}:${parsed.scheduledAt ?? ""}`;

  const { data: existingNotification, error: existingError } = await supabase
    .from("admin_notifications")
    .select("id,status,recipient_count")
    .eq("created_by", admin.userId)
    .eq("idempotency_key", idempotencyKey)
    .maybeSingle<{ id: string; status: AdminNotificationStatus; recipient_count: number | null }>();

  if (existingError && !isAdminNotificationSchemaMissing(existingError)) {
    return failure("BROADCAST_CREATE_FAILED", "Could not verify notification submission state. Please try again.");
  }

  if (existingNotification) {
    revalidatePath("/admin/notifications");
    return success("Notification already submitted. History has been refreshed.", existingNotification.id, {
      inAppRecipientCount: existingNotification.recipient_count ?? 0,
      scheduled: existingNotification.status === "scheduled",
      idempotencyKey,
      warning: safeWarning,
    });
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
      recipient_count: parsed.mode === "draft" ? recipientIds.length : recipientIds.length,
      in_app_success_count: sendNow ? inAppRecipientCount : 0,
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
    return failure("BROADCAST_CREATE_FAILED", "Could not save notification. Please try again.");
  }

  if (parsed.mode !== "draft") {
    const recipientRows = recipientIds.map((userId) => ({
      notification_id: notification.id,
      user_id: userId,
      in_app_status: normalizedChannels.channels.includes("in_app") && sendNow ? "sent" : "pending",
      push_status: normalizedChannels.channels.includes("push") ? "pending" : "skipped",
      email_status: normalizedChannels.channels.includes("email") ? "pending" : "skipped",
      whatsapp_status: normalizedChannels.channels.includes("whatsapp") ? "pending" : "skipped",
      delivered_at: normalizedChannels.channels.includes("in_app") && sendNow ? new Date().toISOString() : null,
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
            message: "Notification was saved, but some recipient records could not be created.",
            broadcastId: notification.id,
            inAppRecipientCount,
            pushEligibleDeviceCount: 0,
            warning: "Some recipient records failed. No raw backend error was exposed.",
            idempotencyKey,
          };
        }
      }
    }
  }

  revalidatePath("/admin/notifications");
  if (parsed.mode === "draft") {
    return success("Draft saved.", notification.id, {
      idempotencyKey,
      warning: safeWarning,
    });
  }
  if (parsed.mode === "test") {
    return success("Test in-app notification recorded for your admin account.", notification.id, {
      inAppRecipientCount,
      idempotencyKey,
      warning: safeWarning,
    });
  }
  if (status === "scheduled") {
    return success("Notification scheduled.", notification.id, {
      inAppRecipientCount,
      scheduled: true,
      idempotencyKey,
      warning: safeWarning,
    });
  }
  return success("In-app notification sent.", notification.id, {
    inAppRecipientCount,
    idempotencyKey,
    warning: safeWarning,
  });
}

export async function loadAudienceCounts(): Promise<AudienceCounts> {
  await requireAdmin();
  const entries = await Promise.all(
    audienceOptions.map(async (option) => [option.value, await countAudience(option.value)] as const),
  );
  return Object.fromEntries(entries) as AudienceCounts;

  async function countAudience(audienceType: AudienceType) {
    const ids = await resolveRecipientIds(audienceType, []);
    return ids.length;
  }
}

async function loadSelectableUsers(role: "candidate" | "employer"): Promise<SelectableUser[]> {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("profiles")
    .select("id,full_name,email")
    .eq("role", role)
    .neq("status", "blocked")
    .order("created_at", { ascending: false })
    .limit(100);
  if (error) return [];
  return (data ?? []).map((row) => ({
    id: row.id as string,
    label: String(row.full_name || row.email || row.id),
    email: (row.email as string | null) ?? null,
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
      "id,title,message,notification_type,audience_type,audience_filters,action_type,action_value,channels,status,recipient_count,in_app_success_count,push_success_count,push_failure_count,failure_summary,idempotency_key,scheduled_at,sent_at,created_by,sent_by,created_at,profiles:created_by(email,full_name)",
    )
    .order("created_at", { ascending: false })
    .limit(25);

  if (status) query = query.eq("status", status);
  if (audience) query = query.eq("audience_type", audience);
  if (type) query = query.eq("notification_type", type);
  if (q) query = query.or(`title.ilike.%${escapeLike(q)}%,message.ilike.%${escapeLike(q)}%`);

  const { data, error } = await query;
  if (error) {
    if (isAdminNotificationSchemaMissing(error)) return [];
    throw error;
  }
  return (data ?? []) as unknown as AdminNotificationRow[];
}

async function resolveRecipientIds(audienceType: AudienceType, selectedUserIds: string[]) {
  const supabase = await createServerSupabaseClient();

  if (audienceType === "selected_candidates" || audienceType === "selected_employers") {
    return [...new Set(selectedUserIds.filter(Boolean))];
  }

  if (audienceType === "pending_documents" || audienceType === "rejected_documents") {
    const statuses = audienceType === "pending_documents" ? ["pending", "pending_review", "pending_verification"] : ["rejected", "resubmission_requested"];
    const [{ data: candidateDocs }, { data: employerDocs }] = await Promise.all([
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
    ]);
    return uniqueIds([
      ...((candidateDocs ?? []).map((row) => row.candidate_id as string | null)),
      ...((employerDocs ?? []).map((row) => row.owner_id as string | null)),
    ]);
  }

  if (audienceType === "paid_candidates" || audienceType === "unpaid_candidates") {
    const { data: memberships } = await supabase
      .from("candidate_memberships")
      .select("candidate_id,status,expires_at")
      .limit(5000);
    const paid = new Set(
      (memberships ?? [])
        .filter((row) => row.status === "active" && (!row.expires_at || new Date(row.expires_at as string) > new Date()))
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
    return uniqueIds((data ?? []).flatMap((row) => [row.candidate_id as string | null, row.employer_id as string | null]));
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

  async function profileIdsByRole(role: "candidate" | "employer" | Array<"candidate" | "employer">) {
    let query = supabase.from("profiles").select("id").neq("status", "blocked").limit(5000);
    query = Array.isArray(role) ? query.in("role", role) : query.eq("role", role);
    const { data } = await query;
    return uniqueIds((data ?? []).map((row) => row.id as string | null));
  }
}

function parseNotificationForm(formData: FormData) {
  const mode = String(formData.get("mode") ?? "draft") as "draft" | "test" | "send";
  const title = String(formData.get("title") ?? "").trim();
  const message = String(formData.get("message") ?? "").trim();
  const audienceType = String(formData.get("audienceType") ?? "all_users") as AudienceType;
  const notificationType = String(formData.get("notificationType") ?? "general_announcement") as AdminNotificationType;
  const channels = formData.getAll("channels").map(String) as DeliveryChannel[];
  const actionType = String(formData.get("actionType") ?? "none") as AdminNotificationActionType;
  const actionValue = String(formData.get("actionValue") ?? "").trim() || null;
  const scheduleMode = String(formData.get("scheduleMode") ?? "now") as "now" | "later";
  const scheduledAt = String(formData.get("scheduledAt") ?? "").trim() || null;
  const selectedUserIds = formData.getAll("selectedUserIds").map(String);
  const idempotencyKey = String(formData.get("idempotencyKey") ?? "").trim() || null;

  if (!["draft", "test", "send"].includes(mode)) return fail("INVALID_ACTION", "Invalid action.");
  if (title.length === 0 || title.length > 140) return fail("INVALID_TITLE", "Title must be 1-140 characters.");
  if (message.length === 0 || message.length > 1200) return fail("INVALID_MESSAGE", "Message must be 1-1200 characters.");
  if (!audienceOptions.some((option) => option.value === audienceType)) return fail("INVALID_AUDIENCE", "Select a valid audience.");
  if (!notificationTypeOptions.some((option) => option.value === notificationType)) return fail("INVALID_TYPE", "Select a valid notification type.");
  if (channels.length === 0) return fail("NO_CHANNEL_SELECTED", "Select at least one notification channel.");
  if (!channels.every((channel) => ["in_app", "push", "email", "whatsapp"].includes(channel))) {
    return fail("INVALID_CHANNEL", "Select valid delivery channels.");
  }
  if (!actionOptions.some((option) => option.value === actionType)) return fail("INVALID_ACTION_LINK", "Select a valid action link.");
  if (actionValue && (!actionValue.startsWith("/") || actionValue.startsWith("//") || actionValue.includes("://"))) {
    return fail("INVALID_ACTION_LINK", "Action links must be internal KAAM routes.");
  }
  if (scheduleMode === "later" && !scheduledAt) return fail("INVALID_SCHEDULE", "Select a scheduled date and time.");
  if (scheduleMode === "later" && scheduledAt && new Date(scheduledAt).getTime() <= Date.now()) {
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

export async function loadPushConfiguration(): Promise<PushConfiguration> {
  return {
    configured: false,
    reason: unavailablePushMessage,
    setupHint:
      "Configure Firebase Android client files, server-side FCM secrets, the push sender Edge Function, and notification migrations before enabling push broadcasts.",
  };
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
  return [...new Set(values.filter((value): value is string => Boolean(value)))];
}

function escapeLike(value: string) {
  return value.replace(/[%_]/g, (match) => `\\${match}`);
}

function isAdminNotificationSchemaMissing(error: unknown) {
  if (!error || typeof error !== "object") return false;
  const maybeError = error as { code?: string; message?: string };
  const message = maybeError.message?.toLowerCase() ?? "";
  return (
    maybeError.code === "42P01" ||
    maybeError.code === "PGRST205" ||
    (message.includes("admin_notifications") && message.includes("schema cache")) ||
    (message.includes("admin_notification_recipients") && message.includes("schema cache"))
  );
}
