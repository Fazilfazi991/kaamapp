# Android Push Notification Manual QA

Use this guide with `Kaam-QA-Push-Test.apk`. Do not use broad audiences while testing push notifications.

## Install

1. Transfer `Kaam-QA-Push-Test.apk` to the Android phone.
2. Open the APK.
3. Allow installation from this source if Android requests it.
4. Install or update the QA app.

If Android reports an incompatible signature:

- Uninstall only the older QA-package app.
- Do not uninstall the production package.
- Reinstall the QA APK.

## Login And Registration

1. Open the QA app.
2. Log in using one approved QA candidate or employer account.
3. Enter OTP manually.
4. Open Notifications.
5. In the Push diagnostics section, request notification permission.
6. Confirm:
   - Firebase initialized: Yes
   - Notification permission: Allowed
   - FCM registration: Registered
   - Supabase device registration: Active

## Foreground Test

1. Keep the app open.
2. In admin web, select one specific QA user.
3. Enable In-app notification and Push notification.
4. Send:
   - Title: `Kaam notification test`
   - Body: `Your QA notification setup is working.`
5. Confirm one visible notification appears.
6. Confirm no duplicate.
7. Confirm diagnostics shows Foreground.

## Background Test

1. Press Home without closing the app.
2. Send another QA-only push.
3. Confirm Android notification appears.
4. Tap it.
5. Confirm app opens to a safe destination.

## Terminated Test

1. Remove the app from recent apps.
2. Send another QA-only push.
3. Confirm notification appears.
4. Tap it.
5. Confirm app launches and restores the session.
6. Confirm a safe destination or notification fallback opens.

## Read/Unread

Test:

- Unread badge
- Notification center
- Mark one read
- Mark all read

## Preferences

1. Disable Push notifications in app preferences.
2. Send In-app notification and Push notification.
3. Confirm in-app arrives and push does not.
4. Re-enable Push notifications.

## Logout

1. Log out.
2. Confirm diagnostics shows device inactive where available.
3. Send another QA push.
4. Confirm push does not arrive.
5. Log back in.
6. Confirm device is active again.

## Blocked User

Using admin:

1. Block only the QA user.
2. Confirm app access is denied.
3. Send a QA push.
4. Confirm no push arrives.
5. Unblock afterward.

## Results

| Test | Pass/Fail | Notes |
| --- | --- | --- |
| Permission | | |
| Registration | | |
| Foreground | | |
| Background | | |
| Terminated | | |
| Deep link | | |
| Read/unread | | |
| Preferences | | |
| Logout | | |
| Blocked user | | |

## Safety Notes

- Do not select All users for push testing.
- Do not print, copy, or share full FCM tokens.
- Do not expose OTPs, private message bodies, storage paths, signed URLs, or credentials.
- The diagnostics summary is intentionally limited to safe status labels only.
