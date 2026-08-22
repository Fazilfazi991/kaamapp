"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { setEmployerVisibility } from "./actions";
import { track } from "@/features/analytics/tracker";

export function MembershipVisibilityToggle({ initialVisible }: { initialVisible: boolean }) {
  const router = useRouter();
  const [visible, setVisible] = useState(initialVisible);
  const [message, setMessage] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function changeVisibility(next: boolean) {
    const previous = visible;
    setVisible(next);
    setMessage(null);
    startTransition(async () => {
      try {
        await setEmployerVisibility(next);
        if (next) track("candidate_visibility_enabled");
        setMessage(next ? "Your profile is now visible to employers." : "Your profile is now hidden from employer searches.");
        router.refresh();
      } catch (error) {
        setVisible(previous);
        setMessage(error instanceof Error ? error.message : "We could not update your profile visibility.");
      }
    });
  }

  return (
    <div className="grid gap-2">
      <label className="flex cursor-pointer items-center justify-between gap-4 rounded-xl border border-[#e6dce8] bg-[#fffcff] p-4" htmlFor="employer-visibility">
        <span><span className="block text-sm font-bold text-[#201925]">Visible to Employers</span><span className="mt-1 block text-xs leading-5 text-[#716674]">{visible ? "Employers can discover your profile and send opportunities." : "Your profile is hidden from new employer searches."}</span></span>
        <span className="relative inline-flex shrink-0 items-center">
          <input id="employer-visibility" type="checkbox" role="switch" checked={visible} disabled={pending} onChange={(event) => changeVisibility(event.target.checked)} className="peer sr-only" />
          <span aria-hidden="true" className="h-7 w-12 rounded-full bg-[#cfc6d1] transition peer-checked:bg-[#160847] peer-disabled:opacity-60" />
          <span aria-hidden="true" className="pointer-events-none absolute left-1 h-5 w-5 rounded-full bg-white shadow transition peer-checked:translate-x-5" />
        </span>
      </label>
      {message ? <p role={message.startsWith("Your profile") ? "status" : "alert"} className="text-sm text-[#514856]">{message}</p> : null}
    </div>
  );
}
