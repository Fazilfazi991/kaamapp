# Kaam Notification Setup

This foundation adds shared in-app notifications, Android FCM delivery, device-token registration, preferences, and safe deep links. Do not apply or deploy these pieces to production until QA signs off.

## Files Added

- `supabase/013_notification_foundation.sql`
- `supabase/functions/send-push-notification/index.ts`
- Flutter notification models, repository, push service, and notification center
- Web candidate, employer, and admin notification pages

## Firebase Android Setup

1. Open Firebase Console and create or select the Kaam Firebase project.
2. Register an Android app with package name:
   - Production: `com.kaamperfectmatch.kaam_perfect_match`
   - QA flavor: `com.kaamperfectmatch.kaam_perfect_match.qa`
3. Download the standard mobile client config file `google-services.json`.
4. Place it at `android/app/google-services.json`.
5. Add the Google Services Gradle plugin only after the file is present:
   - `android/settings.gradle.kts`: plugin `com.google.gms.google-services`
   - `android/app/build.gradle.kts`: apply `com.google.gms.google-services`
6. Run `flutterfire configure` if the team decides to use generated Firebase options instead of Gradle mobile config.

The mobile Firebase config is not a server secret, but never commit server keys, private keys, or service-account JSON to the app.

Current QA setup: `android/app/google-services.json` is present locally for the QA package `com.kaamperfectmatch.kaam_perfect_match.qa`, and the Google Services Gradle plugin is applied. The file is ignored by Git so environment-specific Firebase client configuration is not committed accidentally.

## Supabase Setup

Project: `bhuhojzqxnvwbsypijac`

The notification foundation, admin notification SQL, and admin broadcast push-type compatibility migration were applied to the linked Supabase project `bhuhojzqxnvwbsypijac` during QA setup on 2026-07-17. Verified objects include:

- `notifications`
- `user_push_devices`
- `notification_preferences`
- `admin_notifications`
- `admin_notification_recipients`

All five tables have RLS enabled, with policies and indexes present.

The push Edge Function was deployed after secrets were configured and reviewed:

```bash
supabase functions deploy send-push-notification --project-ref bhuhojzqxnvwbsypijac
```

Required Supabase secrets, names only:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `FIREBASE_SERVICE_ACCOUNT_JSON`

`FIREBASE_SERVICE_ACCOUNT_JSON` must be the server-side Firebase service account JSON used only by the Edge Function. Do not store it in Flutter, web browser code, GitHub, or public environment variables.

Current QA gate: `FIREBASE_SERVICE_ACCOUNT_JSON` is configured as a Supabase secret and `send-push-notification` is deployed with JWT verification enabled. Real foreground, background, and terminated Android delivery still require an attached QA Android device and one selected QA user smoke test.

The migration revokes direct `create_notification` execution from normal authenticated clients. In-app records should be created by audited database triggers, admin review actions, or service-role server processes only.

## Supported Notification Types

- `employer_interest_received`
- `interest_accepted`
- `interest_rejected`
- `match_created`
- `new_message`
- `candidate_document_pending`
- `candidate_document_approved`
- `candidate_document_rejected`
- `candidate_document_resubmission_requested`
- `candidate_accepted_interest`
- `candidate_rejected_interest`
- `employer_document_approved`
- `employer_document_rejected`
- `company_approved`
- `company_rejected`
- `candidate_document_submitted`
- `employer_document_submitted`
- `company_review_submitted`

## Android Behavior

- Android notification channel: `kaam_notifications`
- Android 13 permission: `POST_NOTIFICATIONS`
- The app asks permission from the notification preferences screen, not on the first screen.
- If Firebase is not configured yet, push initialization becomes a safe no-op.
- FCM tokens are registered after session recovery/sign-in and refreshed on token changes.
- Logout deactivates only the current device token.

## Privacy Rules

Push payloads must stay minimal:

- Safe: notification ID, notification type, safe internal route, safe resource IDs
- Not allowed: passport number, DOB, phone, private email, storage path, signed URL, OTP, access token, private chat message body

Chat pushes use generic copy such as "You received a new message."

## QA Procedure

1. Apply the migration in a non-production Supabase project.
2. Configure Firebase Android app and place `google-services.json`.
3. Set Supabase Edge Function secrets in the non-production project.
4. Deploy `send-push-notification`.
5. Sign in as a candidate and open Notifications.
6. Enable push notifications and grant Android permission.
7. Confirm one active row appears in `user_push_devices`.
8. Trigger supported events:
   - employer interest
   - accepted/rejected interest
   - match creation
   - chat message
   - candidate document submission
   - employer document submission
   - candidate document approval/rejection/resubmission request
   - employer document approval/resubmission request
   - company approval/rejection
9. Confirm in-app records appear for the recipient only.
10. Invoke the Edge Function with one test notification ID and confirm one Android push.
11. Confirm disabled push preferences skip push while preserving the in-app record.
12. Confirm logout deactivates the current token.
13. Confirm blocked users do not receive pushes.

Do not send real pushes to production users during development.

## Rollback

Before production rollout, keep this feature behind the migration/function deployment boundary. To roll back before applying the migration, revert the app commit. To roll back after applying the migration, stop invoking the Edge Function, disable triggers if required, and leave historical notification rows intact for audit unless a data-retention decision says otherwise.

## Future Scheduled Phase

Scheduled and automatic server-side notifications are implemented in `supabase/016_scheduled_notifications.sql` and `supabase/functions/process-scheduled-notifications/index.ts`. See `docs/SCHEDULED_NOTIFICATIONS.md` for cron setup, secrets, QA gates, and rollback SQL.
