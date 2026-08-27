import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { routes } from "@/config/routes";
import { safeReturnPath } from "@/lib/auth/routing";
import { supabaseConfig } from "@/lib/supabase/env";

function completeUrl(request: NextRequest, params: Record<string, string | null> = {}) {
  const url = new URL(routes.authComplete, request.url);
  const next = safeReturnPath(request.nextUrl.searchParams.get("next"));
  if (next) url.searchParams.set("next", next);
  for (const [key, value] of Object.entries(params)) {
    if (value) url.searchParams.set(key, value);
  }
  return url;
}

export async function GET(request: NextRequest) {
  const providerError = request.nextUrl.searchParams.get("error");
  if (providerError) {
    return NextResponse.redirect(
      completeUrl(request, { oauthError: providerError === "access_denied" ? "cancelled" : "failed" }),
    );
  }

  const code = request.nextUrl.searchParams.get("code");
  const config = supabaseConfig();
  if (!code || !config) {
    return NextResponse.redirect(completeUrl(request, { oauthError: code ? "failed" : "expired" }));
  }

  const target = completeUrl(request);
  let response = NextResponse.redirect(target);
  response.headers.set("Cache-Control", "private, no-store");
  const supabase = createServerClient(config.url, config.anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, responseHeaders) {
        response = NextResponse.redirect(target);
        cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
        Object.entries(responseHeaders).forEach(([key, value]) => response.headers.set(key, value));
        response.headers.set("Cache-Control", "private, no-store");
      },
    },
  });

  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) return NextResponse.redirect(completeUrl(request, { oauthError: "expired" }));
  return response;
}
