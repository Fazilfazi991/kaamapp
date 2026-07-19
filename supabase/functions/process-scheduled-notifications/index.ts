import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.6";

type ScheduleRow = {
  id: string;
  notification_type: string;
  recipient_id: string;
  title: string;
  body: string;
  action_route: string | null;
  data: Record<string, unknown> | null;
  channels: string[] | null;
  dedupe_key: string;
  source_type: string | null;
  source_id: string | null;
};

type PreferenceRow = {
  push_enabled: boolean;
  in_app_enabled: boolean;
  new_messages_enabled: boolean;
  interests_and_matches_enabled: boolean;
  document_updates_enabled: boolean;
  account_security_enabled: boolean;
};

type DeviceRow = {
  id: string;
};

type PushResult = {
  status?: string;
  accepted_count?: number;
  failed_count?: number;
  reason?: string;
  error?: string;
};

const maxBatchSize = 50;
const sensitivePayloadKeys = new Set([
  "passport_number",
  "dob",
  "date_of_birth",
  "phone",
  "email",
  "storage_path",
  "signed_url",
  "otp",
  "access_token",
  "message_body",
]);

const preferenceByType: Record<string, keyof PreferenceRow> = {
  new_message: "new_messages_enabled",
  employer_interest_received: "interests_and_matches_enabled",
  interest_accepted: "interests_and_matches_enabled",
  interest_rejected: "interests_and_matches_enabled",
  candidate_accepted_interest: "interests_and_matches_enabled",
  candidate_rejected_interest: "interests_and_matches_enabled",
  match_created: "interests_and_matches_enabled",
  match_update: "interests_and_matches_enabled",
  pending_interest_reminder: "interests_and_matches_enabled",
  candidate_document_pending: "document_updates_enabled",
  candidate_document_approved: "document_updates_enabled",
  candidate_document_rejected: "document_updates_enabled",
  candidate_document_resubmission_requested: "document_updates_enabled",
  candidate_document_submitted: "document_updates_enabled",
  employer_document_submitted: "document_updates_enabled",
  employer_document_approved: "document_updates_enabled",
  employer_document_rejected: "document_updates_enabled",
  company_approved: "document_updates_enabled",
  company_rejected: "document_updates_enabled",
  company_review_submitted: "document_updates_enabled",
  document_update: "document_updates_enabled",
  document_expiry_reminder: "document_updates_enabled",
  document_expired: "document_updates_enabled",
  account_alert: "account_security_enabled",
  membership_update: "account_security_enabled",
  membership_expiry_reminder: "account_security_enabled",
  membership_expired: "account_security_enabled",
  incomplete_profile_reminder: "account_security_enabled",
  weekly_summary: "account_security_enabled",
  admin_alert: "account_security_enabled",
  notification_delivery_failure: "account_security_enabled",
  maintenance: "account_security_enabled",
  urgent_alert: "account_security_enabled",
  admin_broadcast: "account_security_enabled",
};

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const scheduledSecret = Deno.env.get("SCHEDULED_NOTIFICATIONS_SECRET");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !serviceRoleKey || !scheduledSecret || !anonKey) {
    return json({
      status: "SERVER_CONFIG_MISSING",
      reason: "Scheduled notification configuration is incomplete.",
    }, 200);
  }

  if (parseBearerToken(request.headers.get("Authorization")) !== scheduledSecret) {
    return json({ error: "Unauthorized" }, 401);
  }

  const requestBody = await request.json().catch(() => ({}));
  const requestedBatchSize = Number((requestBody as { batch_size?: unknown }).batch_size ?? maxBatchSize);
  const batchSize = Math.max(1, Math.min(maxBatchSize, Number.isFinite(requestedBatchSize) ? requestedBatchSize : maxBatchSize));

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: generated, error: generatorError } = await supabase.rpc(
    "generate_automatic_notification_schedules",
  );
  if (generatorError) {
    console.warn("scheduled_notifications generator_failed", safeLog(generatorError.message));
  }

  const { data: schedules, error: claimError } = await supabase.rpc(
    "claim_due_notification_schedules",
    { p_limit: batchSize },
  );
  if (claimError) {
    return json({
      status: "FAILED",
      reason: "Could not claim due notification schedules.",
    }, 500);
  }

  const results = [];
  for (const schedule of (schedules ?? []) as ScheduleRow[]) {
    results.push(await processSchedule({
      supabase,
      schedule,
      supabaseUrl,
      anonKey,
      scheduledSecret,
    }));
  }

  return json({
    status: "OK",
    generated,
    claimed: (schedules ?? []).length,
    results,
  });
});

async function processSchedule({
  supabase,
  schedule,
  supabaseUrl,
  anonKey,
  scheduledSecret,
}: {
  supabase: ReturnType<typeof createClient>;
  schedule: ScheduleRow;
  supabaseUrl: string;
  anonKey: string;
  scheduledSecret: string;
}) {
  try {
    assertSafePayload(schedule.data ?? {});
    const [{ data: profile }, { data: preferences }, { data: devices }] =
      await Promise.all([
        supabase
          .from("profiles")
          .select("id,status")
          .eq("id", schedule.recipient_id)
          .maybeSingle<{ id: string; status: string | null }>(),
        supabase
          .from("notification_preferences")
          .select(
            "push_enabled,in_app_enabled,new_messages_enabled,interests_and_matches_enabled,document_updates_enabled,account_security_enabled",
          )
          .eq("user_id", schedule.recipient_id)
          .maybeSingle<PreferenceRow>(),
        supabase
          .from("user_push_devices")
          .select("id")
          .eq("user_id", schedule.recipient_id)
          .eq("platform", "android")
          .eq("is_active", true)
          .returns<DeviceRow[]>(),
      ]);

    if (!profile || profile.status === "blocked") {
      await markResult(supabase, schedule, {
        status: "skipped",
        skippedCount: 1,
        lastErrorCode: "RECIPIENT_BLOCKED_OR_MISSING",
        failureReason: "Recipient is blocked or missing.",
      });
      return { id: schedule.id, status: "skipped" };
    }

    const preference = preferences ?? defaultPreferences();
    const category = preferenceByType[schedule.notification_type];
    const categoryEnabled = !category || preference[category] !== false;
    const channels = normalizeChannels(schedule.channels);
    const wantsInApp = channels.includes("in_app");
    const wantsPush = channels.includes("push");
    const canCreateInApp = wantsInApp && preference.in_app_enabled && categoryEnabled;
    const canPush = wantsPush && preference.push_enabled && categoryEnabled;

    if (!canCreateInApp && !canPush) {
      await markResult(supabase, schedule, {
        status: "skipped",
        skippedCount: 1,
        lastErrorCode: "PREFERENCES_DISABLED",
        failureReason: "Relevant notification preferences are disabled.",
      });
      return { id: schedule.id, status: "skipped" };
    }

    let notificationId: string | null = null;
    let inAppCreatedCount = 0;
    if (canCreateInApp || canPush) {
      const { data: notification, error } = await supabase
        .from("notifications")
        .insert({
          recipient_id: schedule.recipient_id,
          type: schedule.notification_type,
          title: schedule.title,
          body: schedule.body,
          action_route: schedule.action_route,
          data: schedule.data ?? {},
          dedupe_key: schedule.dedupe_key,
          source_type: schedule.source_type,
          source_id: schedule.source_id,
          push_status: canPush ? "pending" : "skipped",
          last_push_error: canPush ? null : "push preference disabled or not requested",
        })
        .select("id")
        .maybeSingle<{ id: string }>();

      if (error && isDuplicateError(error)) {
        const { data: existing } = await supabase
          .from("notifications")
          .select("id")
          .eq("recipient_id", schedule.recipient_id)
          .eq("dedupe_key", schedule.dedupe_key)
          .maybeSingle<{ id: string }>();
        notificationId = existing?.id ?? null;
        inAppCreatedCount = 0;
      } else if (error || !notification) {
        await markResult(supabase, schedule, {
          status: "failed",
          lastErrorCode: "IN_APP_CREATE_FAILED",
          failureReason: "Could not create canonical notification.",
        });
        return { id: schedule.id, status: "failed" };
      } else {
        notificationId = notification.id;
        inAppCreatedCount = canCreateInApp ? 1 : 0;
      }
    }

    let pushEligibleCount = 0;
    let fcmAcceptedCount = 0;
    let pushFailedCount = 0;
    let skippedCount = 0;
    let failureReason: string | null = null;

    if (canPush && notificationId) {
      pushEligibleCount = (devices ?? []).length;
      if (pushEligibleCount === 0) {
        skippedCount += 1;
        failureReason = "No active Android device.";
        await supabase
          .from("notifications")
          .update({ push_status: "skipped", last_push_error: "no active android devices" })
          .eq("id", notificationId);
      } else {
        const response = await fetch(`${supabaseUrl}/functions/v1/send-push-notification`, {
          method: "POST",
          headers: {
            apikey: anonKey,
            authorization: `Bearer ${scheduledSecret}`,
            "content-type": "application/json",
            "x-kaam-internal-scheduler": "1",
          },
          body: JSON.stringify({ notification_id: notificationId }),
        });
        const pushResult = (await response.json().catch(() => ({}))) as PushResult;
        if (response.ok && pushResult.status === "sent") {
          fcmAcceptedCount = Number(pushResult.accepted_count ?? 1);
          pushFailedCount = Number(pushResult.failed_count ?? 0);
        } else if (pushResult.status === "skipped") {
          skippedCount += 1;
          failureReason = safeReason(pushResult.reason) ?? "Push skipped.";
        } else {
          pushFailedCount = Math.max(1, Number(pushResult.failed_count ?? 1));
          failureReason = safeReason(pushResult.error) ?? "Push delivery failed.";
        }
      }
    } else if (wantsPush) {
      skippedCount += 1;
      failureReason = "Push preference disabled.";
    }

    const finalStatus =
      pushFailedCount > 0 && (inAppCreatedCount > 0 || fcmAcceptedCount > 0)
        ? "partially_sent"
        : pushFailedCount > 0
          ? "failed"
          : "sent";

    await markResult(supabase, schedule, {
      status: finalStatus,
      notificationId,
      inAppCreatedCount,
      pushEligibleCount,
      fcmAcceptedCount,
      pushFailedCount,
      skippedCount,
      lastErrorCode: pushFailedCount > 0 ? "PUSH_FAILED" : null,
      failureReason,
    });

    return { id: schedule.id, status: finalStatus };
  } catch (error) {
    const reason = error instanceof Error ? safeReason(error.message) : "Unknown processing failure.";
    await markResult(supabase, schedule, {
      status: "failed",
      lastErrorCode: "PROCESSING_EXCEPTION",
      failureReason: reason,
    });
    return { id: schedule.id, status: "failed" };
  }
}

async function markResult(
  supabase: ReturnType<typeof createClient>,
  schedule: ScheduleRow,
  result: {
    status: string;
    notificationId?: string | null;
    inAppCreatedCount?: number;
    pushEligibleCount?: number;
    fcmAcceptedCount?: number;
    pushFailedCount?: number;
    skippedCount?: number;
    lastErrorCode?: string | null;
    failureReason?: string | null;
  },
) {
  await supabase.rpc("mark_notification_schedule_result", {
    p_schedule_id: schedule.id,
    p_status: result.status,
    p_in_app_notification_id: result.notificationId ?? null,
    p_in_app_created_count: result.inAppCreatedCount ?? 0,
    p_push_eligible_count: result.pushEligibleCount ?? 0,
    p_fcm_accepted_count: result.fcmAcceptedCount ?? 0,
    p_push_failed_count: result.pushFailedCount ?? 0,
    p_skipped_count: result.skippedCount ?? 0,
    p_last_error_code: result.lastErrorCode ?? null,
    p_failure_reason: result.failureReason ?? null,
  });

  if (schedule.source_type === "admin_notification" && schedule.source_id) {
    await supabase.rpc("refresh_admin_notification_delivery_from_schedules", {
      p_admin_notification_id: schedule.source_id,
    });
  }
}

function normalizeChannels(value: string[] | null) {
  if (!Array.isArray(value)) return ["in_app"];
  return [...new Set(value.filter((channel) => ["in_app", "push"].includes(channel)))];
}

function assertSafePayload(data: Record<string, unknown>) {
  for (const key of Object.keys(data)) {
    if (sensitivePayloadKeys.has(key)) {
      throw new Error(`Unsafe notification payload key: ${key}`);
    }
  }
}

function defaultPreferences(): PreferenceRow {
  return {
    push_enabled: true,
    in_app_enabled: true,
    new_messages_enabled: true,
    interests_and_matches_enabled: true,
    document_updates_enabled: true,
    account_security_enabled: true,
  };
}

function isDuplicateError(error: unknown) {
  if (!error || typeof error !== "object") return false;
  const maybeError = error as { code?: string; message?: string };
  return maybeError.code === "23505" || (maybeError.message ?? "").includes("duplicate key");
}

function parseBearerToken(authHeader: string | null) {
  const match = /^Bearer\s+(.+)$/.exec(authHeader?.trim() ?? "");
  return match?.[1] ?? "";
}

function safeReason(value: unknown) {
  if (typeof value !== "string") return null;
  return value.replace(/[^\w .:-]/g, "").slice(0, 180) || null;
}

function safeLog(value: unknown) {
  return safeReason(value) ?? "unavailable";
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
