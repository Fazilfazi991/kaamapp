import { NextResponse } from "next/server";
import { getAuthenticatedProfile } from "@/lib/auth/session";
import {
  CANDIDATE_MEMBERSHIP_AMOUNT_AED_FILS,
  CANDIDATE_MEMBERSHIP_CURRENCY,
  getStripeClient,
} from "@/lib/stripe";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { createServiceSupabaseClient } from "@/lib/supabase/service";
import { routes } from "@/config/routes";

export const runtime = "nodejs";

function appOrigin(request: Request) {
  return process.env.NEXT_PUBLIC_APP_URL ?? new URL(request.url).origin;
}

export async function POST(request: Request) {
  try {
    const { user, profile } = await getAuthenticatedProfile();
    if (!user || profile?.role !== "candidate" || profile.status !== "active") {
      return NextResponse.json({ error: "Only active Candidate accounts can activate membership." }, { status: 403 });
    }

    const supabase = await createServerSupabaseClient();
    const { data: membership, error: membershipError } = await supabase
      .from("candidate_memberships")
      .select("stripe_customer_id,status,membership_type")
      .eq("candidate_id", user.id)
      .maybeSingle<{ stripe_customer_id: string | null; status: string | null; membership_type: string | null }>();
    if (membershipError) throw membershipError;
    if (membership?.status === "active" && membership.membership_type === "lifetime") {
      return NextResponse.json({ url: `${appOrigin(request)}${routes.candidateMembership}` });
    }

    const stripe = getStripeClient();
    const customerId = membership?.stripe_customer_id ?? (await stripe.customers.create({
      email: user.email ?? undefined,
      name: profile.full_name ?? undefined,
      metadata: { kaam_candidate_id: user.id },
    })).id;

    // This update is performed only by the server and never activates membership.
    const service = createServiceSupabaseClient();
    const { error: customerError } = await service.from("candidate_memberships").upsert(
      { candidate_id: user.id, stripe_customer_id: customerId },
      { onConflict: "candidate_id" },
    );
    if (customerError) throw customerError;

    const origin = appOrigin(request);
    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      customer: customerId,
      client_reference_id: user.id,
      payment_method_types: ["card"],
      line_items: [{
        quantity: 1,
        price_data: {
          currency: CANDIDATE_MEMBERSHIP_CURRENCY,
          unit_amount: CANDIDATE_MEMBERSHIP_AMOUNT_AED_FILS,
          product_data: {
            name: "KAAM Lifetime Membership",
            description: "One-time payment for lifetime candidate membership.",
          },
        },
      }],
      metadata: { purpose: "candidate_membership", candidate_id: user.id },
      success_url: `${origin}${routes.candidateMembershipSuccess}?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}${routes.candidateMembership}?payment=cancelled`,
    });

    if (!session.url) throw new Error("Stripe did not return a Checkout URL.");
    return NextResponse.json({ url: session.url });
  } catch (error) {
    console.error("Candidate membership checkout could not be created", error);
    return NextResponse.json({ error: "Secure checkout is not available yet. Please try again shortly." }, { status: 503 });
  }
}
