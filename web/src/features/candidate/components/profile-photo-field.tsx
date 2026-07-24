import { resolveCandidatePhotoUrl } from "@/lib/candidate-photo";
import { ProfilePhotoPicker } from "./profile-photo-picker";

export async function ProfilePhotoField({ path, name }: { path?: string | null; name?: string | null }) {
  return <ProfilePhotoPicker initialUrl={await resolveCandidatePhotoUrl(path)} name={name} />;
}
