"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { submitPassportIdentityDocuments, uploadPassportSide, type PassportSideUploadResult } from "@/features/candidate/documents/server/actions";

type Side = "front" | "back";
type SideState = PassportSideUploadResult | null;

function PassportSideCard({ side, state, onUploaded }: { side: Side; state: SideState; onUploaded: (result: PassportSideUploadResult) => void }) {
  const [pending, startTransition] = useTransition();
  const label = side === "front" ? "Passport Front" : "Passport Back";
  return <section className="grid gap-3 rounded-xl border border-[#eadde3] p-4">
    <div><h2 className="font-semibold text-[#201925]">{label}</h2><p className="text-sm text-[#66616f]">{side === "front" ? "Information page with the passport details." : "A clear, distinct image of the passport back."}</p></div>
    <input aria-label={label} type="file" accept="image/jpeg,image/png,image/webp" disabled={pending} onChange={(event) => {
      const file = event.currentTarget.files?.[0]; if (!file) return;
      const form = new FormData(); form.set("side", side); form.set("documentFile", file);
      startTransition(async () => onUploaded(await uploadPassportSide(form)));
    }} />
    {pending ? <p className="text-sm text-[#66616f]">Uploading and validating…</p> : null}
    {state?.ok ? <p className="rounded-lg bg-[#f0fff4] p-3 text-sm font-medium text-[#176534]">Accepted. Replace the image to validate a new file.</p> : null}
    {state && !state.ok ? <p role="alert" className="rounded-lg bg-[#fff4f7] p-3 text-sm font-medium text-[#8f1741]">{state.error}</p> : null}
  </section>;
}

export function PassportCanonicalUploadForm() {
  const [front, setFront] = useState<SideState>(null); const [back, setBack] = useState<SideState>(null); const [message, setMessage] = useState(""); const [pending, startTransition] = useTransition();
  const canSubmit = Boolean(front?.ok && back?.ok && front.path && back.path);
  function submit() { if (!canSubmit) return; const form = new FormData(); form.set("frontPath", front!.path!); form.set("backPath", back!.path!); Object.entries(front!.fields ?? {}).forEach(([key, value]) => form.set(key, value)); startTransition(async () => { const result = await submitPassportIdentityDocuments(form); if (!result.ok) { setMessage(result.error ?? "We couldn’t submit your passport."); return; } window.location.assign("/candidate/documents"); }); }
  return <div className="grid gap-5"><p className="text-sm leading-6 text-[#66616f]">Both images are privately uploaded and independently validated before KAAM accepts a passport submission.</p><PassportSideCard side="front" state={front} onUploaded={setFront}/><PassportSideCard side="back" state={back} onUploaded={setBack}/>{message ? <p role="alert" className="rounded-lg bg-[#fff4f7] p-3 text-sm font-medium text-[#8f1741]">{message}</p> : null}<Button type="button" disabled={!canSubmit || pending} onClick={submit}>{pending ? "Submitting…" : "Submit passport for review"}</Button></div>;
}
