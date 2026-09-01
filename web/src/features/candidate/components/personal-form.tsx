"use client";

import { useState } from "react";
import { useFormStatus } from "react-dom";
import { Button } from "@/components/ui/button";
import { Label, SelectField, TextInput } from "@/components/ui/form";
import { routes } from "@/config/routes";
import { nationalities } from "@/features/candidate/constants";
import { candidatePhoneCountries, splitCandidateMobile } from "@/features/candidate/validation";
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
  const [previewUrl, setPreviewUrl] = useState<string | null>(candidate?.profile_photo_url ?? null);
  const initialPhone = splitCandidateMobile(profile?.phone);
  const [phoneError, setPhoneError] = useState("");
  return (
    <form action={savePersonalDetails} className="grid scroll-pb-36 gap-4">
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
      <fieldset className="grid gap-2">
        <Label htmlFor="phone">Mobile number *</Label>
        <div className="grid grid-cols-[8.5rem_minmax(0,1fr)] gap-2">
          <SelectField name="phoneCountryCode" aria-label="Mobile country code" defaultValue={initialPhone.countryCode} required>
            <option value="">Code</option>
            {candidatePhoneCountries.map(({ code, country }) => <option key={code} value={code}>{code} · {country}</option>)}
          </SelectField>
          <TextInput id="phone" name="phone" defaultValue={initialPhone.nationalNumber} inputMode="tel" autoComplete="tel-national" placeholder="50 123 4567" required aria-describedby="phone-help phone-error" onInput={(event) => { event.currentTarget.setCustomValidity(""); setPhoneError(""); }} onInvalid={(event) => { event.currentTarget.setCustomValidity("Enter a valid mobile number."); setPhoneError("Enter a valid mobile number."); }} pattern="[0-9 ()-]{7,15}" />
        </div>
        <p id="phone-help" className="text-xs text-[#66616f]">Choose the country code, then enter the mobile number.</p>
        {initialPhone.isLegacy ? <p className="text-xs text-[#8a5a00]">This saved number uses an older format. Choose the correct country code before updating it.</p> : null}
        {phoneError ? <p id="phone-error" role="alert" className="text-sm font-medium text-[#bc1f55]">{phoneError}</p> : null}
      </fieldset>
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
        {previewUrl ? (
          <div
            role="img"
            aria-label="Current profile photo"
            className="h-24 w-24 rounded-lg bg-cover bg-center"
            style={{ backgroundImage: `url(${previewUrl})` }}
          />
        ) : null}
        <TextInput
          id="profilePhoto"
          name="profilePhoto"
          type="file"
          accept="image/jpeg,image/png,image/webp"
          onChange={(event) => {
            const file = event.currentTarget.files?.[0];
            if (file) setPreviewUrl(URL.createObjectURL(file));
          }}
        />
        <p className="text-xs text-[#66616f]">
          JPG, PNG, or WebP. Maximum 4 MB.
        </p>
      </label>
      <div className="sticky bottom-[calc(4.25rem+env(safe-area-inset-bottom))] z-10 flex gap-3 border-t border-[#f1e6eb] bg-white/95 py-3 backdrop-blur-sm sm:static sm:border-0 sm:bg-transparent sm:py-0 sm:backdrop-blur-none">
        <SaveButton />
      </div>
    </form>
  );
}

function SaveButton() {
  const { pending } = useFormStatus();
  return <Button type="submit" disabled={pending}>{pending ? "Saving profile..." : "Save and continue"}</Button>;
}
