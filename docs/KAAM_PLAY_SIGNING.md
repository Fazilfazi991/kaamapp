# KAAM Google Play upload signing

- Package ID: `com.kaamperfectmatch.kaam_perfect_match`
- Purpose: signs the upload AAB sent to Google Play. This is an **upload key**, not the Google Play app-signing key.
- Upload keystore: `C:\Users\Perfect Elect\SecureKeys\KAAM\kaam-play-upload-key.jks`
- Alias: `kaam-play-upload`
- Certificate SHA-1: `C4:C4:C6:DF:8A:70:94:1C:1D:87:95:65:58:DF:86:D1:00:DC:D8:7A`
- Certificate SHA-256: `2E:8B:C0:AA:14:85:19:20:16:47:A4:98:A1:D4:CF:B0:49:82:94:3A:8B:A6:D5:A2:2E:F8:DD:D7:33:06:9A:36`
- Public certificate: `C:\Users\Perfect Elect\SecureKeys\KAAM\kaam-play-upload-certificate.pem`
- Created: 2026-08-12
- Build helper: `scripts\build-kaam-production.ps1`
- Required environment variable names: `KAAM_STORE_PASSWORD`, `KAAM_KEY_PASSWORD`

Keep both passwords separately in the Fusion Ventures password manager. Do not put passwords in source code, Git, environment files, `key.properties`, or documentation.

Do not replace this upload key casually. Make at least one secure backup of the private keystore outside this repository and keep the passwords separately. Do not copy the private keystore to shared drives or public cloud storage without explicit approval.

Historical reference: `C:\Users\Perfect Elect\kaam-upload-key.jks` is the legacy KAAM keystore. Its passwords are unavailable; it must not be deleted.
