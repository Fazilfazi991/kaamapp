import { Button } from "@/components/ui/button";
import { Label, SelectField, TextInput } from "@/components/ui/form";
import { routes } from "@/config/routes";
import {
  availabilityOptions,
  languages,
  visaStatusOptions,
} from "@/features/candidate/constants";
import { saveExperienceDetails } from "@/features/candidate/server/actions";
import type { CandidateProfileRow } from "@/types/domain";

export function ExperienceForm({
  candidate,
  next = routes.candidateOnboardingReview,
}: {
  candidate: CandidateProfileRow | null;
  next?: string;
}) {
  const selectedLanguages = new Set(candidate?.languages ?? []);
  return (
    <form action={saveExperienceDetails} className="grid gap-4">
      <input type="hidden" name="next" value={next} />
      <label className="grid gap-2">
        <Label htmlFor="availability">Availability *</Label>
        <SelectField
          id="availability"
          name="availability"
          defaultValue={candidate?.availability ?? ""}
          required
        >
          <option value="">Select availability</option>
          {availabilityOptions.map((item) => (
            <option key={item}>{item}</option>
          ))}
        </SelectField>
      </label>
      <label className="grid gap-2">
        <Label htmlFor="experienceYears">Years of experience</Label>
        <TextInput
          id="experienceYears"
          name="experienceYears"
          type="number"
          min="0"
          max="60"
          step="0.5"
          defaultValue={candidate?.experience_years ?? ""}
        />
      </label>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2">
          <Label htmlFor="expectedSalaryMin">Expected salary min</Label>
          <TextInput
            id="expectedSalaryMin"
            name="expectedSalaryMin"
            type="number"
            min="0"
            defaultValue={candidate?.expected_salary_min ?? ""}
          />
        </label>
        <label className="grid gap-2">
          <Label htmlFor="expectedSalaryMax">Expected salary max</Label>
          <TextInput
            id="expectedSalaryMax"
            name="expectedSalaryMax"
            type="number"
            min="0"
            defaultValue={candidate?.expected_salary_max ?? ""}
          />
        </label>
      </div>
      <label className="grid gap-2">
        <Label htmlFor="visaStatus">Visa status</Label>
        <SelectField id="visaStatus" name="visaStatus" defaultValue={candidate?.visa_status ?? ""}>
          <option value="">Select visa status</option>
          {visaStatusOptions.map((item) => (
            <option key={item}>{item}</option>
          ))}
        </SelectField>
      </label>
      <fieldset className="grid gap-3">
        <legend className="text-sm font-semibold text-[#342b38]">Languages</legend>
        <div className="flex flex-wrap gap-2">
          {languages.map((language) => (
            <label
              key={language}
              className="rounded-lg border border-[#eadde3] bg-white px-3 py-2 text-sm font-semibold text-[#342b38]"
            >
              <input
                type="checkbox"
                name="languages"
                value={language}
                defaultChecked={selectedLanguages.has(language)}
                className="mr-2 accent-[#e53670]"
              />
              {language}
            </label>
          ))}
        </div>
      </fieldset>
      <fieldset className="grid gap-3 rounded-lg bg-[#f7f2f5] p-4">
        <legend className="text-sm font-semibold text-[#342b38]">
          Contact visibility
        </legend>
        <label className="flex items-start gap-3 text-sm text-[#3b3340]">
          <input
            type="checkbox"
            name="hidePhoneBeforeMatch"
            defaultChecked={candidate?.hide_phone_before_match ?? true}
            className="mt-1 accent-[#e53670]"
          />
          Hide my phone number until a match allows contact sharing.
        </label>
        <label className="flex items-start gap-3 text-sm text-[#3b3340]">
          <input
            type="checkbox"
            name="hideEmailBeforeMatch"
            defaultChecked={candidate?.hide_email_before_match ?? true}
            className="mt-1 accent-[#e53670]"
          />
          Hide my email until a match allows contact sharing.
        </label>
        <label className="flex items-start gap-3 text-sm text-[#3b3340]">
          <input
            type="checkbox"
            name="isVisible"
            defaultChecked={candidate?.is_visible ?? true}
            className="mt-1 accent-[#e53670]"
          />
          Show my eligible profile to employers.
        </label>
      </fieldset>
      <div className="sticky bottom-16 flex gap-3 bg-white/95 py-3 sm:static">
        <Button type="submit">Save and continue</Button>
      </div>
    </form>
  );
}
