import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.6";

// Invoke from a protected Supabase Cron job once a minute. The scheduler
// secret never leaves the server; this function cannot be used by the app.
Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const secret = Deno.env.get("SCHEDULED_NOTIFICATIONS_SECRET");
  if (!url || !serviceRole || !anonKey || !secret) {
    return json({ status: "SERVER_CONFIG_MISSING" }, 200);
  }
  if (bearer(request.headers.get("Authorization")) !== secret) {
    return json({ error: "Unauthorized" }, 401);
  }
  const client = createClient(url, serviceRole, { auth: { persistSession: false } });
  const { data: jobs, error } = await client.rpc("claim_notification_push_outbox", { p_limit: 25 });
  if (error) return json({ status: "FAILED", reason: "outbox claim failed" }, 500);
  const results = [];
  for (const job of jobs ?? []) {
    const response = await fetch(`${url}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        apikey: anonKey,
        authorization: `Bearer ${secret}`,
        "content-type": "application/json",
        "x-kaam-internal-scheduler": "1",
      },
      body: JSON.stringify({ notification_id: job.notification_id }),
    });
    const body = await response.json().catch(() => ({})) as { status?: string; error?: string; reason?: string };
    const status = body.status === "sent" ? "sent" : body.status === "skipped" ? "skipped" : "failed";
    await client.rpc("finish_notification_push_outbox", {
      p_id: job.id,
      p_status: status,
      p_error: typeof body.error === "string" ? body.error.slice(0, 500) : typeof body.reason === "string" ? body.reason.slice(0, 500) : null,
    });
    results.push({ id: job.id, status });
  }
  return json({ status: "OK", claimed: (jobs ?? []).length, results });
});

function bearer(header: string | null) {
  return /^Bearer\s+(.+)$/.exec(header?.trim() ?? "")?.[1] ?? "";
}
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}
