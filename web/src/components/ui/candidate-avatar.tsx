import { CandidateAvatarImage } from "@/components/ui/candidate-avatar-image";
import { resolveCandidatePhotoUrl } from "@/lib/candidate-photo";
import { photoInitials } from "@/lib/candidate-photo-utils";

export async function CandidateAvatar({
  path,
  name,
  size,
}: {
  path?: string | null;
  name?: string | null;
  size?: number;
}) {
  const src = await resolveCandidatePhotoUrl(path);
  const label = name?.trim() || "Candidate";
  return <CandidateAvatarImage src={src} initials={photoInitials(label)} alt={`${label}'s profile photo`} size={size} />;
}
