"use client";

import { useEffect, useId, useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import {
  submitPassportIdentityDocuments,
  uploadPassportSide,
  type PassportSideUploadResult,
} from "@/features/candidate/documents/server/actions";
import { validateDocumentFile } from "@/features/candidate/documents/validation";

type Side = "front" | "back";
type SideState = PassportSideUploadResult | null;

function PassportSideCard({
  side,
  state,
  onUploaded,
}: {
  side: Side;
  state: SideState;
  onUploaded: (result: SideState) => void;
}) {
  const inputId = useId();
  const [fileName, setFileName] = useState("");
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const isFront = side === "front";
  const label = isFront ? "Passport Front" : "Passport Back";
  const description = isFront
    ? "Information page with the passport details."
    : "A clear, distinct image of the passport back.";

  useEffect(() => () => {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
  }, [previewUrl]);

  function selectFile(file: File | undefined) {
    if (!file) return;

    const validation = validateDocumentFile({
      type: "passport",
      mimeType: file.type,
      size: file.size,
    });
    if (!validation.ok) {
      onUploaded(null);
      setError(validation.error);
      return;
    }

    setError(null);
    setFileName(file.name);
    setPreviewUrl((current) => {
      if (current) URL.revokeObjectURL(current);
      return URL.createObjectURL(file);
    });
    onUploaded(null);

    const form = new FormData();
    form.set("side", side);
    form.set("documentFile", file);
    startTransition(async () => {
      const result = await uploadPassportSide(form);
      if (!result.ok) setError(result.error ?? "We couldn’t validate this image. Please try again.");
      onUploaded(result);
    });
  }

  return (
    <section className="grid gap-3 rounded-xl border border-[#eadde3] bg-white p-4 shadow-sm">
      <div>
        <h2 className="font-semibold text-[#201925]">{label}</h2>
        <p className="mt-1 text-sm text-[#66616f]">{description}</p>
      </div>

      <input
        id={inputId}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        className="sr-only"
        disabled={pending}
        onChange={(event) => selectFile(event.currentTarget.files?.[0])}
        aria-describedby={`${inputId}-help ${error ? `${inputId}-error` : ""}`}
      />
      <div className="flex flex-wrap items-center gap-3">
        <label
          htmlFor={inputId}
          className="focus-ring inline-flex min-h-11 cursor-pointer items-center justify-center rounded-lg bg-[#160847] px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-[#281260]"
        >
          {fileName ? "Change image" : isFront ? "Choose front image" : "Choose back image"}
        </label>
        {fileName ? <span className="min-w-0 break-all text-sm font-medium text-[#514856]">{fileName}</span> : null}
      </div>
      <p id={`${inputId}-help`} className="text-xs text-[#66616f]">
        JPG, PNG, or WebP · Max 10 MB
      </p>

      {previewUrl ? (
        // A browser-created blob URL is only used for this local, pre-upload preview.
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={previewUrl}
          alt={`${label} preview`}
          className="h-36 w-full rounded-lg border border-[#eadde3] bg-[#f7f2f5] object-cover sm:max-w-sm"
        />
      ) : null}
      {pending ? <p className="text-sm text-[#66616f]">Uploading and validating…</p> : null}
      {state?.ok && !pending ? (
        <p className="rounded-lg bg-[#f0fff4] p-3 text-sm font-medium text-[#176534]">
          Accepted. Choose another image to replace it.
        </p>
      ) : null}
      {error ? (
        <p id={`${inputId}-error`} role="alert" className="rounded-lg bg-[#fff4f7] p-3 text-sm font-medium text-[#8f1741]">
          {error}
        </p>
      ) : null}
    </section>
  );
}

export function PassportCanonicalUploadForm() {
  const [front, setFront] = useState<SideState>(null);
  const [back, setBack] = useState<SideState>(null);
  const [message, setMessage] = useState("");
  const [pending, startTransition] = useTransition();
  const canSubmit = Boolean(front?.ok && back?.ok && front.path && back.path);

  function submit() {
    if (!canSubmit || pending) return;

    setMessage("");
    const form = new FormData();
    form.set("frontPath", front!.path!);
    form.set("backPath", back!.path!);
    Object.entries(front!.fields ?? {}).forEach(([key, value]) => form.set(key, value));
    startTransition(async () => {
      const result = await submitPassportIdentityDocuments(form);
      if (!result.ok) {
        setMessage(result.error ?? "We couldn’t submit your passport.");
        return;
      }
      window.location.assign("/candidate/documents");
    });
  }

  return (
    <div className="grid gap-5">
      <p className="text-sm leading-6 text-[#66616f]">
        Both images are privately uploaded and independently validated before KAAM accepts a passport submission.
      </p>
      <PassportSideCard side="front" state={front} onUploaded={setFront} />
      <PassportSideCard side="back" state={back} onUploaded={setBack} />
      {message ? <p role="alert" className="rounded-lg bg-[#fff4f7] p-3 text-sm font-medium text-[#8f1741]">{message}</p> : null}
      <Button type="button" className="w-fit" disabled={!canSubmit || pending} onClick={submit}>
        {pending ? "Submitting..." : "Submit passport for review"}
      </Button>
    </div>
  );
}
