import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { dashboardForRole, safeReturnPath } from "@/lib/auth/routing";
import { routes } from "@/config/routes";
import { supabaseConfig } from "./env";
import { webPerf } from "@/lib/perf";

export async function updateSession(request: NextRequest) {
  const startedAt = performance.now();
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-current-path", request.nextUrl.pathname);
  let response = NextResponse.next({ request: { headers: requestHeaders } });
  const config = supabaseConfig();
  const pathname = request.nextUrl.pathname;
  const isProtected =
    pathname.startsWith("/candidate") || pathname.startsWith("/employer");

  if (!config) {
    if (isProtected) {
      const redirectUrl = request.nextUrl.clone();
      redirectUrl.pathname = routes.login;
      redirectUrl.searchParams.set("redirectTo", pathname);
      return NextResponse.redirect(redirectUrl);
    }
    return response;
  }

  const { url, anonKey } = config;

  const supabase = createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) =>
          request.cookies.set(name, value),
        );
        response = NextResponse.next({ request: { headers: requestHeaders } });
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options),
        );
      },
    },
  });

  // getUser() makes a remote Auth request. This proxy runs for every RSC
  // navigation, so using it here made normal clicks wait on Auth before the
  // route could start. getClaims() verifies an asymmetric JWT locally after
  // the JWKS cache is warm; the server layout still performs the authoritative
  // user/profile authorization before protected content is rendered.
  const { data: claimsResult } = await supabase.auth.getClaims();
  const userId =
    typeof claimsResult?.claims.sub === "string" ? claimsResult.claims.sub : null;
  webPerf("proxy auth claim check", startedAt);

  if (isProtected && !userId) {
    const redirectUrl = request.nextUrl.clone();
    redirectUrl.pathname = routes.login;
    redirectUrl.searchParams.set("redirectTo", pathname);
    return NextResponse.redirect(redirectUrl);
  }

  const isAuthPage = pathname === routes.login || pathname === routes.register;
  if (userId && isAuthPage) {
    const profileStartedAt = performance.now();
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", userId)
      .maybeSingle<{ role: "candidate" | "employer" | "admin" }>();
    webPerf("auth-page profile lookup", profileStartedAt);
    if (profile?.role) {
      const redirectUrl = request.nextUrl.clone();
      const returnPath = safeReturnPath(request.nextUrl.searchParams.get("redirectTo"));
      const destination =
        returnPath?.startsWith(`/${profile.role}`) ? returnPath : dashboardForRole(profile.role);
      redirectUrl.pathname = destination;
      redirectUrl.search = "";
      return NextResponse.redirect(redirectUrl);
    }
  }

  return response;
}
