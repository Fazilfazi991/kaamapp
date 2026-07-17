import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.6";

type NotificationRow = {
  id: string;
  recipient_id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown> | null;
  action_route: string | null;
  push_status: string;
  push_attempts: number;
};

type PreferenceRow = {
  push_enabled: boolean;
  new_messages_enabled: boolean;
  interests_and_matches_enabled: boolean;
  document_updates_enabled: boolean;
  account_security_enabled: boolean;
};

type DeviceRow = {
  id: string;
  fcm_token: string;
  platform: "android" | "web";
};

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

const categoryByType: Record<string, keyof PreferenceRow> = {
  new_message: "new_messages_enabled",
  employer_interest_received: "interests_and_matches_enabled",
  interest_accepted: "interests_and_matches_enabled",
  interest_rejected: "interests_and_matches_enabled",
  candidate_accepted_interest: "interests_and_matches_enabled",
  candidate_rejected_interest: "interests_and_matches_enabled",
  match_created: "interests_and_matches_enabled",
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
  match_update: "interests_and_matches_enabled",
  account_alert: "account_security_enabled",
  membership_update: "account_security_enabled",
  maintenance: "account_security_enabled",
  urgent_alert: "account_security_enabled",
  admin_broadcast: "account_security_enabled",
};

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !serviceRoleKey || !anonKey) {
    return json({
      status: "SERVER_CONFIG_MISSING",
      configured: false,
      reason: "Required Supabase function configuration is missing.",
    }, 200);
  }

  const authHeader = request.headers.get("authorization") ?? "";
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    const authorized = await isAuthorizedAdminCaller(supabaseUrl, anonKey, supabase, authHeader);
    if (!authorized) {
      return json({
        status: "UNAUTHORIZED",
        configured: false,
        reason: "Admin authorization is required.",
      }, 401);
    }
  }

  const requestBody = await request.json().catch(() => ({}));
  if (
    typeof requestBody !== "object" ||
    requestBody === null ||
    Object.keys(requestBody).some((key) => key !== "notification_id" && key !== "health_check")
  ) {
    return json({ error: "Unauthorized" }, 401);
  }

  const firebaseServiceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!firebaseServiceAccountJson) {
    return json({
      status: "SERVER_CONFIG_MISSING",
      configured: false,
      reason: "Required server push configuration is missing.",
    }, 200);
  }

  if ((requestBody as { health_check?: unknown }).health_check === true) {
    return await healthCheck(supabase, firebaseServiceAccountJson);
  }

  const { notification_id: notificationId } = requestBody as { notification_id?: unknown };
  if (typeof notificationId !== "string" || notificationId.length < 10) {
    return json({ error: "notification_id is required" }, 400);
  }

  const { data: notification, error: notificationError } = await supabase
    .from("notifications")
    .select("id, recipient_id, type, title, body, data, action_route, push_status, push_attempts")
    .eq("id", notificationId)
    .maybeSingle<NotificationRow>();

  if (notificationError || !notification) {
    return json({ error: "Notification not found" }, 404);
  }
  if (notification.push_status === "sent") {
    return json({ status: "skipped", reason: "notification already sent" });
  }

  const [{ data: profile }, { data: preferences }, { data: devices }] =
    await Promise.all([
      supabase
        .from("profiles")
        .select("id, status")
        .eq("id", notification.recipient_id)
        .maybeSingle<{ id: string; status: string | null }>(),
      supabase
        .from("notification_preferences")
        .select(
          "push_enabled, new_messages_enabled, interests_and_matches_enabled, document_updates_enabled, account_security_enabled",
        )
        .eq("user_id", notification.recipient_id)
        .maybeSingle<PreferenceRow>(),
      supabase
        .from("user_push_devices")
        .select("id, fcm_token, platform")
        .eq("user_id", notification.recipient_id)
        .eq("is_active", true)
        .eq("platform", "android")
        .returns<DeviceRow[]>(),
    ]);

  if (!profile || profile.status === "blocked") {
    await markSkipped(supabase, notification.id, "recipient blocked or missing");
    return json({ status: "skipped", reason: "recipient blocked or missing" });
  }

  const preference = preferences ?? defaultPreferences();
  const categoryKey = categoryByType[notification.type];
  if (!preference.push_enabled || (categoryKey && preference[categoryKey] === false)) {
    await markSkipped(supabase, notification.id, "push preference disabled");
    return json({ status: "skipped", reason: "push preference disabled" });
  }

  const activeDevices = devices ?? [];
  if (activeDevices.length === 0) {
    await markSkipped(supabase, notification.id, "no active android devices");
    return json({ status: "skipped", reason: "no active android devices" });
  }

  const serviceAccount = JSON.parse(firebaseServiceAccountJson);
  const accessToken = await getFirebaseAccessToken(serviceAccount);
  const endpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
  let payloadData: Record<string, string>;
  try {
    payloadData = safePayloadData(notification);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unsafe notification payload";
    await markFailed(supabase, notification.id, notification.push_attempts, message);
    return json({ status: "failed", error: message }, 400);
  }
  let acceptedCount = 0;
  let failedCount = 0;
  let lastSafeError = "";

  for (const device of activeDevices) {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: device.fcm_token,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: payloadData,
          android: {
            priority: "HIGH",
            notification: {
              channel_id: "kaam_notifications",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
        },
      }),
    });

    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      const errorCode = String(body?.error?.details?.[0]?.errorCode ?? body?.error?.status ?? "");
      if (["UNREGISTERED", "NOT_FOUND", "INVALID_ARGUMENT"].includes(errorCode)) {
        await supabase.from("user_push_devices").update({ is_active: false }).eq("id", device.id);
      }
      failedCount += 1;
      lastSafeError = errorCode || "FCM send failed";
      continue;
    }

    acceptedCount += 1;
  }

  const anySuccess = acceptedCount > 0;
  await supabase
    .from("notifications")
    .update({
      push_status: anySuccess ? "sent" : "failed",
      sent_at: anySuccess ? new Date().toISOString() : null,
      failed_at: anySuccess ? null : new Date().toISOString(),
      push_attempts: notification.push_attempts + 1,
      last_push_error: anySuccess ? null : "All FCM sends failed",
    })
    .eq("id", notification.id);

  return json({
    status: anySuccess ? "sent" : "failed",
    accepted_count: acceptedCount,
    failed_count: failedCount,
    error: anySuccess ? undefined : lastSafeError || "FCM send failed",
  });
});

async function healthCheck(
  supabase: ReturnType<typeof createClient>,
  firebaseServiceAccountJson: string,
) {
  try {
    const parsed = JSON.parse(firebaseServiceAccountJson);
    if (!parsed || typeof parsed.project_id !== "string" || typeof parsed.client_email !== "string") {
      return json({
        status: "SERVER_CONFIG_MISSING",
        configured: false,
        reason: "Firebase service account configuration is incomplete.",
      });
    }
  } catch {
    return json({
      status: "SERVER_CONFIG_MISSING",
      configured: false,
      reason: "Firebase service account configuration is invalid.",
    });
  }

  const [{ error: notificationError }, { error: deviceError }] = await Promise.all([
    supabase.from("notifications").select("id", { head: true, count: "exact" }).limit(1),
    supabase.from("admin_push_device_status").select("id", { head: true, count: "exact" }).limit(1),
  ]);

  if (notificationError || deviceError) {
    return json({
      status: "SCHEMA_MISSING",
      configured: false,
      reason: "Notification schema is not fully available.",
    });
  }

  return json({
    status: "READY",
    configured: true,
    reason: "Push sender is ready.",
  });
}

async function isAuthorizedAdminCaller(
  supabaseUrl: string,
  anonKey: string,
  serviceClient: ReturnType<typeof createClient>,
  authHeader: string,
) {
  if (!authHeader.startsWith("Bearer ")) return false;
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { authorization: authHeader } },
    auth: { persistSession: false },
  });
  const {
    data: { user },
  } = await userClient.auth.getUser();
  if (!user) return false;

  const { data: profile } = await serviceClient
    .from("profiles")
    .select("role,status")
    .eq("id", user.id)
    .maybeSingle<{ role: string | null; status: string | null }>();
  return profile?.role === "admin" && profile.status !== "blocked";
}

function defaultPreferences(): PreferenceRow {
  return {
    push_enabled: true,
    new_messages_enabled: true,
    interests_and_matches_enabled: true,
    document_updates_enabled: true,
    account_security_enabled: true,
  };
}

function safePayloadData(notification: NotificationRow): Record<string, string> {
  const data = notification.data ?? {};
  for (const key of Object.keys(data)) {
    if (sensitivePayloadKeys.has(key)) {
      throw new Error(`Unsafe notification payload key: ${key}`);
    }
  }

  return {
    notification_id: notification.id,
    type: notification.type,
    route: notification.action_route ?? "/notifications",
    ...Object.fromEntries(
      Object.entries(data)
        .filter(([key, value]) => !sensitivePayloadKeys.has(key) && value != null)
        .map(([key, value]) => [key, String(value)]),
    ),
  };
}

async function markSkipped(
  supabase: ReturnType<typeof createClient>,
  notificationId: string,
  reason: string,
) {
  await supabase
    .from("notifications")
    .update({ push_status: "skipped", last_push_error: reason })
    .eq("id", notificationId);
}

async function markFailed(
  supabase: ReturnType<typeof createClient>,
  notificationId: string,
  previousAttempts: number,
  reason: string,
) {
  await supabase
    .from("notifications")
    .update({
      push_status: "failed",
      failed_at: new Date().toISOString(),
      push_attempts: previousAttempts + 1,
      last_push_error: reason,
    })
    .eq("id", notificationId);
}

async function getFirebaseAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
  token_uri?: string;
}) {
  const now = Math.floor(Date.now() / 1000);
  const jwtHeader = { alg: "RS256", typ: "JWT" };
  const jwtClaims = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: serviceAccount.token_uri ?? "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsignedJwt = `${base64Url(JSON.stringify(jwtHeader))}.${base64Url(
    JSON.stringify(jwtClaims),
  )}`;
  const key = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedJwt),
  );
  const assertion = `${unsignedJwt}.${base64UrlBytes(new Uint8Array(signature))}`;
  const response = await fetch(serviceAccount.token_uri ?? "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const body = await response.json();
  if (!response.ok || typeof body.access_token !== "string") {
    throw new Error("Could not obtain Firebase access token");
  }
  return body.access_token as string;
}

async function importPrivateKey(privateKeyPem: string) {
  const pem = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = Uint8Array.from(atob(pem), (char) => char.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    binary,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

function base64Url(value: string) {
  return base64UrlBytes(new TextEncoder().encode(value));
}

function base64UrlBytes(value: Uint8Array) {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
