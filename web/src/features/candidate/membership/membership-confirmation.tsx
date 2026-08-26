"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { trackGoogleAnalyticsEventOnce } from "@/features/analytics/ga4";

export function MembershipConfirmation({ confirmed }: { confirmed: boolean }) {
  const router = useRouter();
  useEffect(() => {
    if (confirmed) {
      trackGoogleAnalyticsEventOnce("membership-payment-success", "membership_payment_success", { membership_type: "lifetime", currency: "AED" });
      return;
    }
    const refreshes = [3500, 9000].map((delay) => window.setTimeout(() => router.refresh(), delay));
    return () => refreshes.forEach(window.clearTimeout);
  }, [confirmed, router]);

  if (confirmed) return null;
  return <p className="mt-3 text-xs leading-5 text-[#716674]">We&apos;ll check twice while Stripe confirms the payment. This page cannot activate membership by itself.</p>;
}
