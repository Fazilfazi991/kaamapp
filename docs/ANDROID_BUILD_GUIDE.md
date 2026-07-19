# Kaam Android Build Guide

Build final Android APKs only from the primary repository folder:

```powershell
C:\Users\Perfect Elect\Desktop\Website Projects\KAAM APP
```

Use the `develop` branch for QA and pre-merge Android builds. Temporary Git worktrees can be useful for isolated coding, but do not use them for final APK builds because ignored local environment files can drift from the primary folder.

## Required Local Files

These files are required locally and must stay ignored by Git:

- `.env`
- `.env.production`
- `.env.qa`
- `android/app/google-services.json`

Do not commit Supabase keys, Firebase private material, service-role keys, signing keys, APKs, or app bundles. The committed `.env.example` may contain placeholders only.

For the original production app, `.env` and `.env.production` must point to the production Supabase project and include a valid public anon key. `android/app/google-services.json` must be the production Firebase client for the original package.

## Package IDs

- Production flavor: `com.kaamperfectmatch.kaam_perfect_match`
- QA flavor: `com.kaamperfectmatch.kaam_perfect_match.qa`

The production app label is `Kaam`. The QA app label is `Kaam QA`.

## Build Commands

From the primary folder:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --flavor production
```

The production debug APK is written to:

```powershell
build\app\outputs\flutter-apk\app-production-debug.apk
```

To build QA:

```powershell
flutter build apk --debug --flavor qa --dart-define=KAAM_ENV_FILE=.env.qa
```

## APK Verification

Use Android build tools to confirm the package and label:

```powershell
& "C:\Android\Sdk\build-tools\36.0.0\aapt.exe" dump badging "build\app\outputs\flutter-apk\app-production-debug.apk" |
  Select-String -Pattern "^package:|^application-label:"
```

Expected production output includes:

```text
package: name='com.kaamperfectmatch.kaam_perfect_match'
application-label:'Kaam'
```

If startup configuration is invalid, the app shows an internal build configuration screen instead of silently continuing to login with placeholder Supabase values.
