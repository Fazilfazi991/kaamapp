"use client";

import { useMemo, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import type { CandidateDocumentType } from "@/features/candidate/documents/types";

export function DocumentUploadForm({
  type,
  title,
  description,
  action,
}: {
  type: CandidateDocumentType;
  title: string;
  description: string;
  action: (formData: FormData) => Promise<void>;
}) {
  const cameraRef = useRef<HTMLInputElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const [fileName, setFileName] = useState("");
  const [source, setSource] = useState<"camera" | "file" | null>(null);
  const [stage, setStage] = useState("");
  const accept = useMemo(
    () => (type === "passport" ? "image/jpeg,image/png,image/webp" : "image/jpeg,image/png,image/webp,application/pdf"),
    [type],
  );

  function syncSelected(input: HTMLInputElement | null) {
    const file = input?.files?.[0];
    setFileName(file?.name ?? "");
    setSource(input === cameraRef.current ? "camera" : "file");
    setStage(file ? "Ready for secure upload" : "");
    const other = input === cameraRef.current ? fileRef.current : cameraRef.current;
    if (other) other.value = "";
  }

  return (
    <form
      action={action}
      onSubmit={() => setStage(type === "passport" ? "Uploading securely and reading details..." : "Uploading securely...")}
      className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm"
    >
      <div>
        <h2 className="text-lg font-semibold text-[#201925]">{title}</h2>
        <p className="mt-2 text-sm leading-6 text-[#66616f]">{description}</p>
      </div>

      <input
        ref={cameraRef}
        type="file"
        name={source === "camera" ? "documentFile" : "cameraDocumentFile"}
        accept="image/jpeg,image/png,image/webp"
        capture="environment"
        className="sr-only"
        onChange={(event) => syncSelected(event.currentTarget)}
      />
      <input
        ref={fileRef}
        type="file"
        name={source === "file" ? "documentFile" : "deviceDocumentFile"}
        accept={accept}
        className="sr-only"
        onChange={(event) => syncSelected(event.currentTarget)}
      />

      <div className="mt-5 grid gap-3 sm:grid-cols-2">
        <button
          type="button"
          onClick={() => cameraRef.current?.click()}
          className="focus-ring rounded-lg border border-[#eadde3] bg-[#fffafc] p-5 text-left transition hover:border-[#e53670]"
        >
          <span className="text-sm font-semibold text-[#201925]">Take Photo</span>
          <span className="mt-1 block text-sm leading-6 text-[#66616f]">
            Open the device camera and capture the document.
          </span>
        </button>
        <button
          type="button"
          onClick={() => fileRef.current?.click()}
          className="focus-ring rounded-lg border border-[#eadde3] bg-[#fffafc] p-5 text-left transition hover:border-[#e53670]"
        >
          <span className="text-sm font-semibold text-[#201925]">Choose from Device</span>
          <span className="mt-1 block text-sm leading-6 text-[#66616f]">
            Select an existing file from gallery or files.
          </span>
        </button>
      </div>

      <div className="mt-5 rounded-lg bg-[#f7f2f5] p-4 text-sm text-[#3b3340]">
        <p className="font-semibold">{fileName || "No file selected"}</p>
        <p className="mt-1 text-[#66616f]">
          {stage || "Files are stored in the private KAAM bucket and reviewed before approval."}
        </p>
      </div>

      <div className="mt-5">
        <Button type="submit" disabled={!fileName}>
          Continue
        </Button>
      </div>
    </form>
  );
}
