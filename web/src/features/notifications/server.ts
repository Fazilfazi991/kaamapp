"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import type { UserRole } from "@/types/domain";
import type { NotificationPreferencesRow, NotificationRow } from "./model";
import { safeNotificationHref } from "./model";

export async function loadNotificationsForUser({
  userId,
  unreadOnly = false,
}: {
  userId: string;
  unreadOnly?: boolean;
}) {
  const supabase = await createServerSupabaseClient();
  let query = supabase
    .from("notifications")
    .select("id,type,title,body,status,read_at,created_at,action_route,data")
    .eq("recipient_id", userId);
  if (unreadOnly) query = query.eq("status", "unread");
  const { data, error } = await query.order("created_at", { ascending: false }).limit(100);
  if (error) {
    if (isNotificationSchemaMissing(error)) return [];
    throw error;
  }
  return (data ?? []) as NotificationRow[];
}

export async function loadNotificationPreferences(userId: string) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("notification_preferences")
    .select(
      "push_enabled,in_app_enabled,email_enabled,whatsapp_enabled,new_messages_enabled,interests_and_matches_enabled,document_updates_enabled,account_security_enabled",
    )
    .eq("user_id", userId)
    .maybeSingle<NotificationPreferencesRow>();
  if (error) {
    if (isNotificationSchemaMissing(error)) return defaultPreferences();
    throw error;
  }
  return data ?? defaultPreferences();
}

export async function markNotificationReadAction(formData: FormData) {
  const notificationId = String(formData.get("notificationId") ?? "");
  const currentPath = String(formData.get("currentPath") ?? "/");
  if (!notificationId) return;
  const supabase = await createServerSupabaseClient();
  await supabase
    .from("notifications")
    .update({ status: "read", read_at: new Date().toISOString() })
    .eq("id", notificationId);
  revalidatePath(currentPath);
}

export async function openNotificationAction(formData: FormData) {
  const notificationId = String(formData.get("notificationId") ?? "");
  const role = String(formData.get("role") ?? "candidate") as UserRole;
  const type = String(formData.get("type") ?? "");
  const actionRoute = String(formData.get("actionRoute") ?? "");
  const currentPath = String(formData.get("currentPath") ?? "/");
  if (notificationId) await markNotificationReadAction(formData);
  revalidatePath(currentPath);
  redirect(safeNotificationHref({ role, type, actionRoute }));
}

export async function markAllNotificationsReadAction(formData: FormData) {
  const userId = String(formData.get("userId") ?? "");
  const currentPath = String(formData.get("currentPath") ?? "/");
  if (!userId) return;
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase
    .from("notifications")
    .update({ status: "read", read_at: new Date().toISOString() })
    .eq("recipient_id", userId)
    .eq("status", "unread");
  if (error && !isNotificationSchemaMissing(error)) throw error;
  revalidatePath(currentPath);
}

export async function saveNotificationPreferencesAction(formData: FormData) {
  const userId = String(formData.get("userId") ?? "");
  const currentPath = String(formData.get("currentPath") ?? "/");
  if (!userId) return;
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.from("notification_preferences").upsert(
    {
      user_id: userId,
      push_enabled: formData.get("push_enabled") === "on",
      in_app_enabled: formData.get("in_app_enabled") === "on",
      new_messages_enabled: formData.get("new_messages_enabled") === "on",
      interests_and_matches_enabled:
        formData.get("interests_and_matches_enabled") === "on",
      document_updates_enabled: formData.get("document_updates_enabled") === "on",
      account_security_enabled: formData.get("account_security_enabled") === "on",
      email_enabled: false,
      whatsapp_enabled: false,
    },
    { onConflict: "user_id" },
  );
  if (error && !isNotificationSchemaMissing(error)) throw error;
  revalidatePath(currentPath);
}

function defaultPreferences(): NotificationPreferencesRow {
  return {
    push_enabled: true,
    in_app_enabled: true,
    email_enabled: false,
    whatsapp_enabled: false,
    new_messages_enabled: true,
    interests_and_matches_enabled: true,
    document_updates_enabled: true,
    account_security_enabled: true,
  };
}

function isNotificationSchemaMissing(error: unknown) {
  if (!error || typeof error !== "object") return false;
  const maybeError = error as { code?: string; message?: string };
  const message = maybeError.message?.toLowerCase() ?? "";
  return (
    maybeError.code === "42P01" ||
    maybeError.code === "PGRST205" ||
    message.includes("notifications") && message.includes("schema cache") ||
    message.includes("notification_preferences") && message.includes("schema cache")
  );
}
