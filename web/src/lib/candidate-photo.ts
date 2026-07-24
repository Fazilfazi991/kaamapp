import "server-only";

import { cache } from "react";
import { createServerSupabaseClient } from "@/lib/supabase/server";
export { isStoredPhotoPath, photoInitials } from "@/lib/candidate-photo-utils";

const signedUrlLifetimeSeconds = 60 * 10;

// React cache is scoped to the current server request. This avoids duplicate
// signed-URL calls during one render without sharing a URL between accounts.
export const resolveCandidatePhotoUrl = cache(async (value?: string | null) => {
  const photo = value?.trim() ?? "";
  if (!photo) return null;
  if (/^https?:\/\//i.test(photo)) return photo;

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.storage
    .from("kaam-private")
    .createSignedUrl(photo, signedUrlLifetimeSeconds);

  return error || !data?.signedUrl ? null : data.signedUrl;
});
