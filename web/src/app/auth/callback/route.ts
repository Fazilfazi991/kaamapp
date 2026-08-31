import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { routes } from "@/config/routes";
import { parseAuthJourney, safeReturnPath } from "@/lib/auth/routing";
import { authCallbackCredential } from "@/lib/auth/callback-credential";
import { supabaseConfig } from "@/lib/supabase/env";

function completeUrl(request: NextRequest, params: Record<string, string | null> = {}) {
  const url = new URL(routes.authComplete, request.url);
  const next = safeReturnPath(request.nextUrl.searchParams.get("next"));
  const journey = parseAuthJourney(request.nextUrl.searchParams.get("journey"));
  if (next) url.searchParams.set("next", next);
  if (journey) url.searchParams.set("journey", journey);
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

  const credential = authCallbackCredential(request.nextUrl.searchParams);
  const config = supabaseConfig();
  if (!credential || !config) {
    return NextResponse.redirect(
      completeUrl(request, { oauthError: credential ? "failed" : "expired" }),
    );
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

  const { error } = credential.kind === "code"
    ? await supabase.auth.exchangeCodeForSession(credential.value)
    : await supabase.auth.verifyOtp({ token_hash: credential.value, type: "magiclink" });
  if (error) return NextResponse.redirect(completeUrl(request, { oauthError: "expired" }));
  return response;
}
