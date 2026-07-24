"use client";

import Image from "next/image";
import { useState } from "react";

export function CandidateAvatarImage({
  src,
  initials,
  alt,
  size = 64,
}: {
  src: string | null;
  initials: string;
  alt: string;
  size?: number;
}) {
  const [failed, setFailed] = useState(false);
  const showImage = Boolean(src) && !failed;

  return (
    <div
      className="relative shrink-0 overflow-hidden rounded-full bg-[#f7e8ef]"
      style={{ width: size, height: size }}
    >
      {showImage ? (
        <Image
          src={src!}
          alt={alt}
          width={size}
          height={size}
          className="h-full w-full object-cover"
          onError={() => setFailed(true)}
        />
      ) : (
        <span
          aria-label={src ? `${alt} photo could not be loaded` : `${alt} has no profile photo`}
          className="grid h-full w-full place-items-center text-sm font-bold text-[#bc1f55]"
        >
          {initials}
        </span>
      )}
    </div>
  );
}
