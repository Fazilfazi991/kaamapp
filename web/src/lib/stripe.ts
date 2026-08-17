import "server-only";

import Stripe from "stripe";

export const CANDIDATE_MEMBERSHIP_AMOUNT_AED_FILS = 5_000;
export const CANDIDATE_MEMBERSHIP_CURRENCY = "aed";
export const CANDIDATE_MEMBERSHIP_MONTHS = 2;

export function getStripeClient() {
  const secretKey = process.env.STRIPE_SECRET_KEY;
  if (!secretKey) throw new Error("Stripe test credentials are not configured for this environment.");
  return new Stripe(secretKey);
}

export function requireStripeWebhookSecret() {
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!webhookSecret) throw new Error("Stripe webhook signing secret is not configured for this environment.");
  return webhookSecret;
}
