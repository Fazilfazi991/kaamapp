"use client";

import { Button } from "@/components/ui/button";

export default function CandidateError({
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="mx-auto max-w-2xl rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <h1 className="text-xl font-bold text-[#201925]">Could not complete that step</h1>
      <p className="mt-2 text-sm leading-6 text-[#66616f]">
        Please check the entered details and try again. If the issue continues, contact Kaam support.
      </p>
      <Button type="button" onClick={reset} className="mt-4">
        Try again
      </Button>
    </div>
  );
}
