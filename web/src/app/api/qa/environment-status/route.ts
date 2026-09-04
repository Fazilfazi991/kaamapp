import { NextResponse } from "next/server";

const qaSupabaseRef = "skswbbcimwvwmuiapjnd";
const productionSupabaseRef = "bhuhojzqxnvwbsypijac";

function supabaseRef() {
  const configuredUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ??
    process.env.NEXT_PUBLIC_KAAM_SUPABASE_URL ?? "";
  try {
    return new URL(configuredUrl).hostname.match(/^([a-z0-9]+)\.supabase\.co$/)?.[1] ?? null;
  } catch {
    return null;
  }
}

export function previewEnvironmentStatus() {
  const ref = supabaseRef();
  const stripeSecret = process.env.STRIPE_SECRET_KEY ?? "";
  return {
    supabase: ref === qaSupabaseRef
      ? "QA"
      : ref === productionSupabaseRef
        ? "PRODUCTION"
        : "UNKNOWN",
    supabaseProjectRef: ref,
    stripe: stripeSecret.startsWith("sk_test_")
      ? "TEST"
      : stripeSecret.startsWith("sk_live_")
        ? "LIVE"
        : "UNKNOWN",
  } as const;
}

export async function GET() {
  if (process.env.VERCEL_ENV !== "preview") {
    return new NextResponse(null, { status: 404 });
  }
  return NextResponse.json(previewEnvironmentStatus(), {
    headers: { "Cache-Control": "private, no-store, max-age=0" },
  });
}
