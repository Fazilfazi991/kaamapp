import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const repoRoot = join(__dirname, "../../../../..");

function readRepoFile(path: string) {
  return readFileSync(join(repoRoot, path), "utf8");
}

describe("scheduled notification architecture", () => {
  it("adds a durable schedule table with idempotency and safe claiming", () => {
    const migration = readRepoFile("supabase/016_scheduled_notifications.sql");

    expect(migration).toContain("create table if not exists public.notification_schedules");
    expect(migration).toContain("notification_schedules_recipient_dedupe_idx");
    expect(migration).toContain("for update skip locked");
    expect(migration).toContain("claim_due_notification_schedules");
  });

  it("runs schedules through a server-side Edge Function and shared secret", () => {
    const processor = readRepoFile(
      "supabase/functions/process-scheduled-notifications/index.ts",
    );
    const sender = readRepoFile(
      "supabase/functions/send-push-notification/index.ts",
    );

    expect(processor).toContain("SCHEDULED_NOTIFICATIONS_SECRET");
    expect(processor).toContain("generate_automatic_notification_schedules");
    expect(processor).toContain("ENABLE_AUTOMATIC_NOTIFICATION_GENERATORS");
    expect(processor).toContain("claim_due_notification_schedules");
    expect(sender).toContain("SCHEDULED_NOTIFICATIONS_SECRET");
    expect(sender).toContain('mode: "scheduler"');
  });

  it("keeps private message content out of scheduled push bodies", () => {
    const migration = readRepoFile("supabase/016_scheduled_notifications.sql");
    const foundation = readRepoFile("supabase/013_notification_foundation.sql");
    const processor = readRepoFile(
      "supabase/functions/process-scheduled-notifications/index.ts",
    );

    expect(foundation).toContain("'You received a new message.'");
    expect(migration).toContain("message_body");
    expect(processor).toContain("sensitivePayloadKeys");
    expect(processor).toContain("assertSafePayload");
  });

  it("documents five-minute cron and rollback", () => {
    const docs = readRepoFile("docs/SCHEDULED_NOTIFICATIONS.md");
    const migration = readRepoFile("supabase/016_scheduled_notifications.sql");

    expect(docs).toContain("*/5 * * * *");
    expect(docs).toContain("cron.unschedule('kaam-process-scheduled-notifications')");
    expect(migration).toContain("kaam-process-scheduled-notifications");
  });
});
