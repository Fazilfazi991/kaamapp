import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { dashboardForRole, safeReturnPath } from "@/lib/auth/routing";
import { routes } from "@/config/routes";
import { supabaseConfig } from "./env";

export async function updateSession(request: NextRequest) {
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

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (isProtected && !user) {
    const redirectUrl = request.nextUrl.clone();
    redirectUrl.pathname = routes.login;
    redirectUrl.searchParams.set("redirectTo", pathname);
    return NextResponse.redirect(redirectUrl);
  }

  const isAuthPage = pathname === routes.login || pathname === routes.register;
  if (user && isAuthPage) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle<{ role: "candidate" | "employer" | "admin" }>();
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
