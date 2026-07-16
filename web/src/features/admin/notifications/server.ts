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
  type SelectableUser,
} from "./types";

const supportedSendChannels = new Set<DeliveryChannel>(["in_app"]);

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
  const [counts, candidates, employers, history] = await Promise.all([
    loadAudienceCounts(),
    loadSelectableUsers("candidate"),
    loadSelectableUsers("employer"),
    loadNotificationHistory({ q, status, audience, type }),
  ]);

  return {
    counts,
    candidates,
    employers,
    history,
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
  if (!parsed.ok) return { ok: false, message: parsed.message };

  const recipientIds =
    parsed.mode === "test" ? [admin.userId] : await resolveRecipientIds(parsed.audienceType, parsed.selectedUserIds);
  if (recipientIds.length === 0 && parsed.mode !== "draft") {
    return { ok: false, message: "No recipients match this audience." };
  }

  const unsupportedChannels = parsed.channels.filter((channel) => !supportedSendChannels.has(channel));
  if (parsed.mode !== "draft" && unsupportedChannels.length > 0) {
    return {
      ok: false,
      message:
        "Push, Email, and WhatsApp delivery are not configured yet. Use in-app only, or save this notification as a draft.",
    };
  }

  const sendNow = parsed.mode !== "draft" && parsed.scheduleMode === "now";
  const status: AdminNotificationStatus =
    parsed.mode === "draft" ? "draft" : parsed.scheduleMode === "later" ? "scheduled" : "sent";

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
      channels: parsed.channels,
      status,
      recipient_count: parsed.mode === "draft" ? recipientIds.length : recipientIds.length,
      scheduled_at: parsed.scheduleMode === "later" ? parsed.scheduledAt : null,
      sent_at: sendNow ? new Date().toISOString() : null,
      created_by: admin.userId,
      sent_by: sendNow ? admin.userId : null,
    })
    .select("id")
    .maybeSingle<{ id: string }>();

  if (error || !notification) {
    if (isAdminNotificationSchemaMissing(error)) {
      return {
        ok: false,
        message:
          "Admin notification tables are not applied in Supabase yet. Apply supabase/013_admin_notifications.sql first.",
      };
    }
    return { ok: false, message: "Could not save notification. Please try again." };
  }

  if (parsed.mode !== "draft") {
    const recipientRows = recipientIds.map((userId) => ({
      notification_id: notification.id,
      user_id: userId,
      in_app_status: parsed.channels.includes("in_app") && sendNow ? "sent" : "pending",
      push_status: parsed.channels.includes("push") ? "pending" : "skipped",
      email_status: parsed.channels.includes("email") ? "pending" : "skipped",
      whatsapp_status: parsed.channels.includes("whatsapp") ? "pending" : "skipped",
      delivered_at: parsed.channels.includes("in_app") && sendNow ? new Date().toISOString() : null,
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
            message: "Notification was saved, but some recipient records could not be created.",
          };
        }
      }
    }
  }

  revalidatePath("/admin/notifications");
  if (parsed.mode === "draft") return { ok: true, message: "Draft saved." };
  if (parsed.mode === "test") return { ok: true, message: "Test in-app notification recorded for your admin account." };
  if (status === "scheduled") return { ok: true, message: "Notification scheduled." };
  return { ok: true, message: "In-app notification sent." };
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
      "id,title,message,notification_type,audience_type,audience_filters,action_type,action_value,channels,status,recipient_count,scheduled_at,sent_at,created_by,sent_by,created_at,profiles:created_by(email,full_name)",
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

  if (!["draft", "test", "send"].includes(mode)) return fail("Invalid action.");
  if (title.length === 0 || title.length > 140) return fail("Title must be 1-140 characters.");
  if (message.length === 0 || message.length > 1200) return fail("Message must be 1-1200 characters.");
  if (!audienceOptions.some((option) => option.value === audienceType)) return fail("Select a valid audience.");
  if (!notificationTypeOptions.some((option) => option.value === notificationType)) return fail("Select a valid notification type.");
  if (channels.length === 0) return fail("Select at least one delivery channel.");
  if (!channels.every((channel) => ["in_app", "push", "email", "whatsapp"].includes(channel))) {
    return fail("Select valid delivery channels.");
  }
  if (!actionOptions.some((option) => option.value === actionType)) return fail("Select a valid action link.");
  if (actionValue && (!actionValue.startsWith("/") || actionValue.startsWith("//") || actionValue.includes("://"))) {
    return fail("Action links must be internal KAAM routes.");
  }
  if (scheduleMode === "later" && !scheduledAt) return fail("Select a scheduled date and time.");

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
  };
}

function fail(message: string) {
  return { ok: false as const, message };
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
