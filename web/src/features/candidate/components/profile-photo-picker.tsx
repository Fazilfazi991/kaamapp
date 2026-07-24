"use client";

import { useEffect, useState } from "react";
import { CandidateAvatarImage } from "@/components/ui/candidate-avatar-image";

export function ProfilePhotoPicker({
  initialUrl,
  name,
}: {
  initialUrl: string | null;
  name?: string | null;
}) {
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  useEffect(
    () => () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    },
    [previewUrl],
  );

  return (
    <>
      <CandidateAvatarImage
        src={previewUrl ?? initialUrl}
        initials={(name ?? "K").trim().slice(0, 1).toUpperCase() || "K"}
        alt="Current profile photo"
        size={96}
      />
      <input
        id="profilePhoto"
        name="profilePhoto"
        type="file"
        accept="image/jpeg,image/png,image/webp"
        onChange={(event) => {
          const file = event.target.files?.[0];
          if (!file) return;
          setPreviewUrl((previous) => {
            if (previous) URL.revokeObjectURL(previous);
            return URL.createObjectURL(file);
          });
        }}
        className="focus-ring w-full rounded-lg border border-[#dfd2d9] bg-white px-4 py-3 text-base text-[#201925] shadow-sm"
      />
    </>
  );
}
