# Android release and update workflow

KAAM uses three complementary mechanisms: Supabase `public.app_config` changes public runtime values, Shorebird patches Dart-only changes, and Google Play AAB releases deliver native, asset, dependency-native, permission, signing, or Flutter-engine changes. Google Play is always the source of truth for store-update availability.

## Versioning and environments

Use `version: MAJOR.MINOR.PATCH+BUILD` in `pubspec.yaml`; increment `BUILD` for every Play upload. Build `production` with `--flavor production --dart-define=KAAM_ENVIRONMENT=production`. QA is a separate Android application ID (`.qa`). Never place secrets in `app_config` or Flutter assets. Preserve the exact Git revision, Flutter version, `pubspec.lock`, AAB and signing identity used for every Shorebird base release.

## Supabase configuration

Apply `supabase/migrations/025_remote_app_config.sql`. Manage rows only through an admin/service-role context. Anonymous and signed-in apps can read only enabled, effective production rows. The app caches validated values, times out quickly, and falls back to built-in defaults. Enable maintenance only after verifying the message; retry refreshes it. Set a forced minimum only after the higher version is live on Play.

## Shorebird

Install and authenticate locally, then initialize the real Shorebird app ID (do not invent one):

```powershell
shorebird doctor
shorebird login
shorebird init --display-name "KAAM"
shorebird release android --flavor production
```

Commit the generated `shorebird.yaml` and its `pubspec.yaml` asset entry. Do not commit access tokens. Preview a release with `shorebird preview`; create a Dart-only patch with `shorebird patch android --flavor production`. Stop/roll back a bad patch in the Shorebird console before users restart. A patch cannot change native Kotlin/Java, plugins with new native components, permissions, assets/fonts, Firebase configuration, package ID, signing, or Flutter version—use a new Play release.

## Google Play release

Create and securely back up an upload keystore twice. Then create ignored `android/key.properties` with placeholders:

```properties
storeFile=C:\secure\kaam-upload.jks
storePassword=<password>
keyAlias=<alias>
keyPassword=<password>
```

Generate it if needed: `keytool -genkeypair -v -keystore C:\secure\kaam-upload.jks -alias <alias> -keyalg RSA -keysize 4096 -validity 10000`. Enable Play App Signing, build the AAB, upload first to Internal Testing, then test Google Sign-In, FCM, maintenance, forced update and flexible update. In-app updates only behave on a Play-delivered build.

## Decision and rollback

| Change | Delivery |
| --- | --- |
| Flag, message, maintenance | Supabase configuration |
| Dart-only bug fix, no assets | Shorebird patch |
| Native/assets/plugin/Firebase/permission/version change | Google Play release |

For an incident: enable maintenance; disable the affected flag or Shorebird patch; release a Play hotfix if native code is involved. Never force an update to a version unavailable to the user’s Play track.

## Local validation

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build appbundle --release --flavor production
git diff --check
```
