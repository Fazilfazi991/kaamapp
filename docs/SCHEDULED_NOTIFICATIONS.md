# Kaam Scheduled Notifications

This phase adds server-side scheduled and automatic notifications. Flutter does not schedule or poll for these jobs.

## Reused Architecture

- `notifications`: canonical in-app feed and push source rows.
- `notification_preferences`: category and channel preferences.
- `user_push_devices` / `admin_push_device_status`: active Android device eligibility.
- `send-push-notification`: existing FCM sender, now callable by either an admin JWT or the internal scheduler secret.
- Existing database triggers: immediate interest, match, message, document, company, and admin review notifications.
- `admin_notifications` and `admin_notification_recipients`: admin broadcast request/history records.

## Added Objects

- Migration: `supabase/016_scheduled_notifications.sql`
- Table: `notification_schedules`
- Edge Function: `supabase/functions/process-scheduled-notifications/index.ts`
- Automatic schedule generators:
  - document expiry reminders: 30 days, 7 days, 1 day, expiry day
  - membership expiry reminders: 7 days, 3 days, 1 day, expired
  - pending interest reminder after 24 hours
  - incomplete profile reminders after 24 hours, 3 days, 7 days
  - weekly summary on Sunday evening UAE time
  - admin alerts for pending docs and delivery failures

Immediate match and new-message notifications remain trigger-driven, and the scheduler can push them when they are represented as schedules.

## Cron

Name: `kaam-process-scheduled-notifications`

Schedule: `*/5 * * * *`

Function URL:

```text
https://bhuhojzqxnvwbsypijac.supabase.co/functions/v1/process-scheduled-notifications
```

Authentication method:

- `Authorization: Bearer <SCHEDULED_NOTIFICATIONS_SECRET>`
- The same secret must be configured on both `process-scheduled-notifications` and `send-push-notification`.
- The processor uses `SUPABASE_SERVICE_ROLE_KEY` only inside the trusted Edge Function.

Required Edge Function secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SCHEDULED_NOTIFICATIONS_SECRET`
- `FIREBASE_SERVICE_ACCOUNT_JSON` for the push sender

Required Postgres settings for the migration cron block:

```sql
alter database postgres set app.settings.supabase_url = 'https://bhuhojzqxnvwbsypijac.supabase.co';
alter database postgres set app.settings.scheduled_notifications_secret = '<same scheduler secret>';
```

Rollback cron SQL:

```sql
select cron.unschedule('kaam-process-scheduled-notifications');
```

To pause delivery without deleting history:

```sql
update public.notification_schedules
set status = 'cancelled',
    failure_reason = 'Scheduler paused by admin.',
    processed_at = now(),
    updated_at = now()
where status in ('pending', 'failed');
```

## Preference Mapping

- `push_enabled`: required for push.
- `in_app_enabled`: required for in-app rows.
- `new_messages_enabled`: `new_message`.
- `interests_and_matches_enabled`: interests, matches, pending-interest reminders.
- `document_updates_enabled`: document and company review/update reminders.
- `account_security_enabled`: membership, incomplete profile, weekly summary, admin/system alerts.

If push is disabled or no active Android device exists, the scheduler creates in-app only when allowed. If all relevant preferences are disabled, the schedule is marked `skipped` with a safe reason.

## Timezone

- `notification_schedules.scheduled_at` is stored as UTC `timestamptz`.
- Admin scheduled notifications accept an explicit timezone; default is `Asia/Dubai`.
- Automatic weekly summaries target Sunday evening in UAE time.

## QA Checklist

Use approved QA users only.

1. Schedule one admin notification 5 minutes ahead for one QA user.
2. Confirm it executes while the app is closed.
3. Confirm one `notifications` row appears.
4. Confirm Android push appears when the QA device is active.
5. Run the processor twice and confirm no duplicate in-app row or duplicate push.
6. Disable push preference and confirm in-app only.
7. Test a no-device user and confirm in-app only.
8. Block a QA user and confirm schedule is skipped.
9. Cancel a pending schedule and confirm it does not send.
10. Force a failed schedule, retry it, and confirm attempts/delivery counts update safely.

`FCM accepted` means Firebase accepted the send request. It does not confirm the device displayed the notification.
