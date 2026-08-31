"use client";

import { useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { routes } from "@/config/routes";

export function FinishOnboardingButton({ disabled }: { disabled: boolean }) {
  const router = useRouter();
  const [opening, setOpening] = useState(false);
  const [isPending, startTransition] = useTransition();

  useEffect(() => {
    if (!disabled) router.prefetch(routes.candidateDashboard);
  }, [disabled, router]);

  function openDashboard() {
    if (disabled || opening) return;

    setOpening(true);
    startTransition(() => {
      router.replace(routes.candidateDashboard);
    });
  }

  return (
    <Button type="button" disabled={disabled || opening || isPending} onClick={openDashboard}>
      {opening || isPending ? "Finishing..." : "Finish and open dashboard"}
    </Button>
  );
}
