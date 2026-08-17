import { NextResponse } from "next/server";
import type Stripe from "stripe";
import {
  CANDIDATE_MEMBERSHIP_AMOUNT_AED_FILS,
  CANDIDATE_MEMBERSHIP_CURRENCY,
  getStripeClient,
  requireStripeWebhookSecret,
} from "@/lib/stripe";
import { createServiceSupabaseClient } from "@/lib/supabase/service";

export const runtime = "nodejs";

function sessionCandidateId(session: Stripe.Checkout.Session) {
  const candidateId = session.metadata?.candidate_id;
  return session.metadata?.purpose === "candidate_membership" && candidateId && session.client_reference_id === candidateId
    ? candidateId
    : null;
}

function validMembershipPayment(session: Stripe.Checkout.Session) {
  return session.payment_status === "paid"
    && session.amount_total === CANDIDATE_MEMBERSHIP_AMOUNT_AED_FILS
    && session.currency === CANDIDATE_MEMBERSHIP_CURRENCY;
}

async function recordFailedPayment(event: Stripe.Event, session: Stripe.Checkout.Session) {
  const candidateId = sessionCandidateId(session);
  if (!candidateId) return;
  const service = createServiceSupabaseClient();
  const { error } = await service.rpc("record_stripe_candidate_membership_payment_failure", {
    p_candidate_id: candidateId,
    p_checkout_session_id: session.id,
    p_payment_intent_id: typeof session.payment_intent === "string" ? session.payment_intent : null,
    p_stripe_event_id: event.id,
  });
  if (error) throw error;
}

async function fulfill(event: Stripe.Event, session: Stripe.Checkout.Session) {
  const candidateId = sessionCandidateId(session);
  if (!candidateId || !validMembershipPayment(session)) throw new Error("Invalid Candidate membership Checkout session.");
  const service = createServiceSupabaseClient();
  const { error } = await service.rpc("fulfill_stripe_candidate_membership_payment", {
    p_candidate_id: candidateId,
    p_checkout_session_id: session.id,
    p_payment_intent_id: typeof session.payment_intent === "string" ? session.payment_intent : null,
    p_stripe_customer_id: typeof session.customer === "string" ? session.customer : null,
    p_stripe_event_id: event.id,
    p_paid_at: new Date(event.created * 1000).toISOString(),
    p_is_test: !event.livemode,
  });
  if (error) throw error;
}

export async function POST(request: Request) {
  const signature = request.headers.get("stripe-signature");
  if (!signature) return NextResponse.json({ error: "Missing Stripe signature." }, { status: 400 });

  try {
    const event = getStripeClient().webhooks.constructEvent(await request.text(), signature, requireStripeWebhookSecret());
    if (event.type === "checkout.session.completed" || event.type === "checkout.session.async_payment_succeeded") {
      await fulfill(event, event.data.object as Stripe.Checkout.Session);
    } else if (event.type === "checkout.session.async_payment_failed") {
      await recordFailedPayment(event, event.data.object as Stripe.Checkout.Session);
    }
    return NextResponse.json({ received: true });
  } catch (error) {
    console.error("Stripe webhook rejected or could not be fulfilled", error);
    return NextResponse.json({ error: "Webhook could not be processed." }, { status: 400 });
  }
}
