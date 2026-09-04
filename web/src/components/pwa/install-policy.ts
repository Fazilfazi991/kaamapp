const stableInstallRoutes = new Set([
  "/candidate/dashboard",
  "/candidate/jobs",
  "/candidate/matches",
  "/candidate/messages",
  "/candidate/profile",
  "/employer/dashboard",
  "/employer/search",
  "/employer/job-posts",
  "/employer/messages",
  "/employer/profile",
]);

export function isStableInstallRoute(pathname: string) {
  return stableInstallRoutes.has(pathname);
}

export function isSafeUpdateRoute(pathname: string) {
  return pathname === "/" || isStableInstallRoute(pathname);
}
