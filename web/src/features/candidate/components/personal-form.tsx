import { Button } from "@/components/ui/button";
import { Label, SelectField, TextInput } from "@/components/ui/form";
import { routes } from "@/config/routes";
import { nationalities } from "@/features/candidate/constants";
import { savePersonalDetails } from "@/features/candidate/server/actions";
import type { CandidateProfileRow, ProfileRow } from "@/types/domain";

export function PersonalForm({
  profile,
  candidate,
  next = routes.candidateOnboardingSkills,
}: {
  profile: ProfileRow | null;
  candidate: CandidateProfileRow | null;
  next?: string;
}) {
  return (
    <form action={savePersonalDetails} className="grid gap-4">
      <input type="hidden" name="next" value={next} />
      <label className="grid gap-2">
        <Label htmlFor="fullName">Full name *</Label>
        <TextInput
          id="fullName"
          name="fullName"
          defaultValue={profile?.full_name ?? ""}
          autoComplete="name"
          required
        />
      </label>
      <label className="grid gap-2">
        <Label htmlFor="phone">Mobile number *</Label>
        <TextInput
          id="phone"
          name="phone"
          defaultValue={profile?.phone ?? ""}
          inputMode="tel"
          autoComplete="tel"
          placeholder="+971 50 000 0000"
          required
        />
      </label>
      <label className="grid gap-2">
        <Label htmlFor="nationality">Nationality *</Label>
        <SelectField
          id="nationality"
          name="nationality"
          defaultValue={candidate?.nationality ?? ""}
          required
        >
          <option value="">Select nationality</option>
          {nationalities.map((nationality) => (
            <option key={nationality}>{nationality}</option>
          ))}
        </SelectField>
      </label>
      <label className="grid gap-2">
        <Label htmlFor="bio">Short profile introduction</Label>
        <textarea
          id="bio"
          name="bio"
          defaultValue={candidate?.bio ?? ""}
          rows={4}
          className="focus-ring w-full rounded-lg border border-[#dfd2d9] bg-white px-4 py-3 text-base text-[#201925] shadow-sm"
          placeholder="Briefly describe your work experience."
        />
      </label>
      <label className="grid gap-2">
        <Label htmlFor="profilePhoto">Profile photo</Label>
        {candidate?.profile_photo_url ? (
          <div
            role="img"
            aria-label="Current profile photo"
            className="h-24 w-24 rounded-lg bg-cover bg-center"
            style={{ backgroundImage: `url(${candidate.profile_photo_url})` }}
          />
        ) : null}
        <TextInput
          id="profilePhoto"
          name="profilePhoto"
          type="file"
          accept="image/jpeg,image/png,image/webp"
        />
        <p className="text-xs text-[#66616f]">
          JPG, PNG, or WebP. Maximum 4 MB.
        </p>
      </label>
      <div className="sticky bottom-16 flex gap-3 bg-white/95 py-3 sm:static">
        <Button type="submit">Save and continue</Button>
      </div>
    </form>
  );
}
