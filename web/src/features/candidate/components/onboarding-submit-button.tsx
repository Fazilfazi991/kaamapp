"use client";

import { useFormStatus } from "react-dom";
import { Button } from "@/components/ui/button";

export function OnboardingSubmitButton({
  disabled = false,
}: {
  disabled?: boolean;
}) {
  const { pending } = useFormStatus();

  return (
    <Button type="submit" disabled={disabled || pending}>
      {pending ? "Saving..." : "Save and continue"}
    </Button>
  );
}
