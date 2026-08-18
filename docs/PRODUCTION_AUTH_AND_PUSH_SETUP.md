# KAAM production authentication and push setup

## Security boundary

The Flutter application contains only `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`GOOGLE_WEB_CLIENT_ID`. Never add Firebase service-account JSON, a Google OAuth
client secret, or a Supabase service-role key to an app build or repository.

## Google authentication

1. Confirm the Android application ID is `com.kaamperfectmatch.kaam_perfect_match`.
   Create separate Google OAuth Android clients for the production and QA package
   names, and add both debug and release SHA-1/SHA-256 signing fingerprints.
2. Create iOS OAuth clients after setting the final iOS bundle IDs. Add the
   reversed client ID URL scheme to `ios/Runner/Info.plist`.
3. Create a Web OAuth client. Put its client ID in the ignored `.env` as
   `GOOGLE_WEB_CLIENT_ID`, or pass it with `--dart-define`; do not add its
   secret to Flutter.
4. In Supabase Dashboard → Authentication → Providers, enable Google and use
   the Web client ID and its client secret there. Add every production and QA
   redirect URL used by the auth configuration.
5. Enable account-linking only through Supabase’s supported identity flow.
   This implementation intentionally never merges users by matching emails in
   Flutter. Verify the desired Supabase identity-linking policy with a test
   account before releasing.
6. Because Google is offered on iOS, add Sign in with Apple before App Store
   submission unless Apple confirms an exception for the exact distribution.

## Firebase and mobile platforms

1. In Firebase, register Android and iOS apps matching the final package/bundle
   IDs. Download `android/app/google-services.json` and
   `ios/Runner/GoogleService-Info.plist`; both are gitignored.
2. Android already declares `POST_NOTIFICATIONS` and applies the Google
   services Gradle plugin. Ensure the Firebase JSON is present for every build
   flavor and use real release signing rather than the current debug release
   signing configuration.
3. Create the iOS Flutter platform on macOS if it is not in the repository,
   add the Firebase plist, enable Push Notifications and Background Modes →
   Remote notifications in Xcode, and upload an APNs auth key in Firebase.
   A simulator cannot validate APNs delivery.
4. Deploy `send-push-notification`, `process-scheduled-notifications`, and
   `process-notification-push-outbox` Edge Functions. Set these server secrets:
   `FIREBASE_SERVICE_ACCOUNT_JSON`, `SCHEDULED_NOTIFICATIONS_SECRET`, plus the
   Supabase-provided service-role variables. Keep all of them server-only.
5. Apply migration `supabase/migrations/024_production_push_hardening.sql` after
   the existing notification migrations. Create a protected Supabase Cron job
   that POSTs to `process-notification-push-outbox` every minute using
   `SCHEDULED_NOTIFICATIONS_SECRET`; scheduled notifications retain their
   existing processor. Exercise the job with a non-production test user first.

## Release verification

Test fresh install, allow/deny/permanently-deny permission, Google account
selection after logout, foreground/background/terminated message taps, token
refresh, and an invalid-token cleanup on physical Android and iPhone devices.
Confirm a push only opens allowlisted in-app destinations after the authenticated
profile role has been rechecked; notification payloads must contain no PII.
