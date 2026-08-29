export const KAAM_PRODUCTION_ORIGIN = "https://www.kaamcareer.com";

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

function isDevelopmentOrigin(url: URL) {
  return (url.hostname === "localhost" || url.hostname === "127.0.0.1") &&
    (url.protocol === "http:" || url.protocol === "https:");
}

function isVercelPreviewOrigin(url: URL) {
  return url.protocol === "https:" && url.hostname.endsWith(".vercel.app");
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
  const currentUrl = new URL(currentOrigin);
  const current = currentUrl.origin;
  let origin = KAAM_PRODUCTION_ORIGIN;

  if (kaamProductionOrigins.has(current)) {
    origin = KAAM_PRODUCTION_ORIGIN;
  } else if (isDevelopmentOrigin(currentUrl) || isVercelPreviewOrigin(currentUrl)) {
    origin = current;
  } else {
    origin = trustedKaamOrigin(configuredSiteUrl) ?? KAAM_PRODUCTION_ORIGIN;
  }

  return new URL("/auth/callback", origin).toString();
}
