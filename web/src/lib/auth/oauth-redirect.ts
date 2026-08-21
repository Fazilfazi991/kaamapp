const kaamProductionOrigins = new Set([
  "https://kaamcareer.com",
  "https://www.kaamcareer.com",
]);

function trustedKaamOrigin(value: string | undefined) {
  if (!value) return null;

  try {
    const origin = new URL(value).origin;
    return kaamProductionOrigins.has(origin) ? origin : null;
  } catch {
    return null;
  }
}

/**
 * Keeps production OAuth on the intentional KAAM host while allowing preview
 * and local environments to retain their own safe origin.
 */
export function oauthCallbackUrl({
  currentOrigin,
  configuredSiteUrl,
}: {
  currentOrigin: string;
  configuredSiteUrl?: string;
}) {
  const current = new URL(currentOrigin).origin;
  const canonical = trustedKaamOrigin(configuredSiteUrl);
  const origin = kaamProductionOrigins.has(current) && canonical ? canonical : current;

  return new URL("/auth/callback", origin).toString();
}
