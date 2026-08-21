"use client";

import { useState } from "react";

export function MembershipCheckoutButton({ label }: { label: string }) {
  const [message, setMessage] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function startCheckout() {
    setLoading(true);
    setMessage(null);
    try {
      const response = await fetch("/api/stripe/candidate-membership/checkout", { method: "POST" });
      const payload = (await response.json()) as { url?: string; error?: string };
      if (!response.ok || !payload.url) throw new Error(payload.error ?? "Unable to start secure checkout.");
      window.location.assign(payload.url);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Unable to start secure checkout.");
      setLoading(false);
    }
  }

  return (
    <div className="grid gap-2">
      <button type="button" onClick={startCheckout} disabled={loading} className="w-fit min-h-10 whitespace-nowrap rounded-lg bg-[#160847] px-4 py-2 text-sm font-semibold text-white hover:bg-[#261069] disabled:cursor-not-allowed disabled:opacity-60">
        {loading ? "Opening secure checkout…" : label}
      </button>
      {message ? <p className="text-sm text-[#a12a4d]" role="alert">{message}</p> : null}
    </div>
  );
}
