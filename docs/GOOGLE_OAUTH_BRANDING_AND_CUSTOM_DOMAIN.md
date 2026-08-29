# Google OAuth branding and custom auth domain

Status: implementation-ready runbook. No Google Cloud, Supabase, DNS, Vercel, or production setting has been changed by this document.

## Google Auth Platform settings

Enter these values in the Google Auth Platform project used by KAAM's existing web OAuth client:

- App name: `KAAM`
- User support email: a monitored KAAM/Fusion Ventures address
- App logo: `web/public/brand/kaam-google-oauth-120.png` (120 × 120 PNG)
- Application home page: `https://www.kaamcareer.com`
- Privacy policy: `https://www.kaamcareer.com/privacy`
- Terms of service: `https://www.kaamcareer.com/terms`
- Authorized domain: `kaamcareer.com`
- Developer contact email: a monitored engineering/operations address

Complete Google's branding verification after the production deployment makes all three public URLs return a direct `200` response. Branding verification controls the consent-screen app name, logo, links, and trust state. It does **not** replace the OAuth redirect host: while Supabase Auth uses its project URL, Google can still display `bhuhojzqxnvwbsypijac.supabase.co` as the domain receiving account information.

The current Google web OAuth client must retain this authorized redirect URI:

`https://bhuhojzqxnvwbsypijac.supabase.co/auth/v1/callback`

KAAM's application callback is separate and must be allowed in Supabase Auth redirect URLs:

`https://www.kaamcareer.com/auth/callback`

Keep `prompt: "select_account"` in the application OAuth request.

## Future `auth.kaamcareer.com` migration

Supabase custom domains are a paid add-on available to projects on a paid plan. The repository cannot prove the production project's current subscription or add-on entitlement; verify eligibility in the Supabase dashboard before purchasing or configuring it. A custom domain applies to Auth, REST, Storage, Realtime, and Functions on that project, not only OAuth.

### Prepare without activating

1. In Supabase Dashboard → Project Settings → Custom Domains, begin the flow for `auth.kaamcareer.com`, but do not activate it.
2. Supabase will provide authoritative DNS targets. Create exactly the returned records. The expected shape is:
   - `CNAME` host `auth` → the Supabase-provided custom-domain target (placeholder only; do not guess it).
   - `TXT` host `_acme-challenge.auth` → the Supabase-provided certificate-verification value (placeholder only; do not guess it).
3. If the DNS provider proxies records, use DNS-only mode during validation unless Supabase's current dashboard instructions explicitly permit proxying.
4. Wait for DNS propagation and successful certificate verification in Supabase. Do not activate yet.
5. Add the future Google authorized redirect URI while retaining the current URI:
   - Existing: `https://bhuhojzqxnvwbsypijac.supabase.co/auth/v1/callback`
   - Future: `https://auth.kaamcareer.com/auth/v1/callback`
6. Confirm both redirect URIs are saved on the same Google OAuth client used by Supabase.

### Staged activation

1. Schedule a low-traffic window and capture the current Supabase, Google, Vercel, web, and Flutter settings for rollback.
2. Activate `auth.kaamcareer.com` in Supabase only after DNS, TLS, and both Google callback URIs are ready. Supabase Auth begins advertising the custom domain immediately after activation; the original project domain remains available.
3. Validate Google login through the existing web configuration before changing client environment variables.
4. Set production `NEXT_PUBLIC_SUPABASE_URL=https://auth.kaamcareer.com` in Vercel. Keep the existing anon/publishable key unchanged and never place service-role or OAuth client secrets in `NEXT_PUBLIC_*` variables.
5. Redeploy through the normal reviewed release workflow. Confirm candidate, employer, admin, account-setup/no-role, logout, token refresh, and middleware flows.
6. Update Flutter's Supabase URL to `https://auth.kaamcareer.com` in a separately tested mobile release. Ensure any deep-link allow-list and platform callback configuration still matches the app's existing OAuth return scheme.
7. Keep both Google redirect URIs during the rollout and for the lifetime of older supported mobile builds that may still initiate authentication through the project domain. Remove the old URI only after logs prove it is unused and all supported clients have migrated.

The canonical Vercel variables after migration are expected to be:

```text
NEXT_PUBLIC_SITE_URL=https://www.kaamcareer.com
NEXT_PUBLIC_SUPABASE_URL=https://auth.kaamcareer.com
```

These are future values only; this change does not apply them.

## Sessions, cookies, and risk controls

- Existing Supabase sessions are token-based and the original project domain remains active, so activation is not intended to revoke them. Changing the API/Auth origin can nevertheless affect refresh, storage, CORS, cookie scope, or an older client. Treat session continuity as a release gate and test with already-signed-in candidate, employer, and admin accounts.
- Web auth cookies are scoped to the KAAM web host by the SSR integration; changing the upstream Supabase API host should not deliberately change the KAAM cookie domain. Verify this in production-like QA rather than assuming continuity.
- Do not change Google client secrets, rotate Supabase keys, or remove the old callback as part of the domain cutover.
- Confirm Storage, Edge Function, REST, and Realtime consumers because the Supabase custom domain is project-wide.
- Test Flutter login and refresh on the oldest supported release before retiring the old host.

## Rollback

If authentication, refresh, API, Storage, Realtime, or Functions regress: restore the prior Vercel and Flutter Supabase URL, redeploy/re-release as appropriate, and keep both Google callback URIs. Follow the Supabase dashboard's current custom-domain deactivation procedure only after client traffic is back on the project URL. Do not delete DNS verification records or the old Google callback until recovery is confirmed.
