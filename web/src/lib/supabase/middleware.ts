import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { dashboardForRole, isBlockedStatus, isRoleRoute, safeReturnPath } from "@/lib/auth/routing";
import { routes } from "@/config/routes";
import { supabaseConfig } from "./env";

export function usesVerifiedClaimsForPath(pathname: string) {
  return pathname === routes.candidateOnboarding || pathname.startsWith(`${routes.candidateOnboarding}/`);
}

export function isCandidateOnboardingServerAction(pathname: string, method: string, hasNextActionHeader: boolean) {
  return usesVerifiedClaimsForPath(pathname) && method === "POST" && hasNextActionHeader;
}

export async function updateSession(request: NextRequest) {
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-current-path", request.nextUrl.pathname);
  let response = NextResponse.next({ request: { headers: requestHeaders } });
  const config = supabaseConfig();
  const pathname = request.nextUrl.pathname;
  const isBlockedPage = pathname === routes.accountBlocked;
  const isProtected =
    isRoleRoute(pathname, "candidate") ||
    isRoleRoute(pathname, "employer") ||
    pathname.startsWith("/admin");
  const loginRoute = isRoleRoute(pathname, "employer")
    ? routes.employerLogin
    : routes.candidateLogin;

  if (!config) {
    if (isProtected) {
      const redirectUrl = request.nextUrl.clone();
      redirectUrl.pathname = loginRoute;
      redirectUrl.searchParams.set("redirectTo", pathname);
      return NextResponse.redirect(redirectUrl);
    }
    return response;
  }

  const { url, anonKey } = config;

  // The Server Action verifies signed claims itself. Avoid doing the same
  // authentication work twice on this latency-sensitive POST request.
  if (isCandidateOnboardingServerAction(pathname, request.method, request.headers.has("next-action"))) {
    return response;
  }

  const supabase = createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, responseHeaders) {
        cookiesToSet.forEach(({ name, value }) =>
          request.cookies.set(name, value),
        );
        response = NextResponse.next({ request: { headers: requestHeaders } });
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options),
        );
        Object.entries(responseHeaders).forEach(([key, value]) =>
          response.headers.set(key, value),
        );
      },
    },
  });

  let authenticatedUserId: string | null = null;
  if (usesVerifiedClaimsForPath(pathname)) {
    const { data } = await supabase.auth.getClaims();
    authenticatedUserId = data?.claims.sub ?? null;
  } else {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    authenticatedUserId = user?.id ?? null;
  }

  if (isProtected && !authenticatedUserId) {
    const redirectUrl = request.nextUrl.clone();
    redirectUrl.pathname = loginRoute;
    redirectUrl.searchParams.set("redirectTo", pathname);
    return NextResponse.redirect(redirectUrl);
  }

  const isAuthPage =
    pathname === routes.login ||
    pathname === routes.register ||
    pathname === routes.candidateLogin ||
    pathname === routes.candidateRegister ||
    pathname === routes.employerLogin ||
    pathname === routes.employerRegister;
  // Protected routes perform their role/status check in their server layout or page.
  // Keeping the proxy to session renewal and unauthenticated redirects lets the
  // application shell start streaming without a second profile request.
  if (authenticatedUserId && (isAuthPage || isBlockedPage)) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("role,status")
      .eq("id", authenticatedUserId)
      .maybeSingle<{ role: "candidate" | "employer" | "admin"; status: string | null }>();

    if (isBlockedStatus(profile?.status) && !isBlockedPage) {
      const redirectUrl = request.nextUrl.clone();
      redirectUrl.pathname = routes.accountBlocked;
      redirectUrl.search = "";
      return NextResponse.redirect(redirectUrl);
    }

    if (isAuthPage && profile?.role) {
      const redirectUrl = request.nextUrl.clone();
      const returnPath = safeReturnPath(request.nextUrl.searchParams.get("redirectTo"));
      const destination =
        returnPath && isRoleRoute(returnPath, profile.role) ? returnPath : dashboardForRole(profile.role);
      redirectUrl.pathname = destination;
      redirectUrl.search = "";
      return NextResponse.redirect(redirectUrl);
    }
  }

  return response;
}
