import { Button, ButtonLink } from "@/components/ui/button";
import { SelectField, TextInput } from "@/components/ui/form";
import { availabilityOptions, indianStates, uaeEmirates } from "@/features/candidate/constants";
import { experienceOptions } from "@/features/employer/search/filters";
import type { CandidateSearchFilters, EmployerLookupData } from "@/features/employer/types";

export function EmployerSearchForm({
  filters,
  lookups,
}: {
  filters: CandidateSearchFilters;
  lookups: EmployerLookupData;
}) {
  const category = lookups.categories.find((item) => item.name === filters.category);
  const skills = category
    ? lookups.skills.filter((skill) => skill.category_id === category.id)
    : lookups.skills;

  return (
    <form className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <div className="grid gap-4 md:grid-cols-2">
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
          Search
          <TextInput name="q" defaultValue={filters.q} placeholder="Name, skill, city, language" />
        </label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
          Main skill category
          <SelectField name="category" defaultValue={filters.category}>
            <option value="">Any category</option>
            {lookups.categories.map((item) => (
              <option key={item.id} value={item.name}>
                {item.name}
              </option>
            ))}
          </SelectField>
        </label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
          Skill
          <SelectField name="skill" defaultValue={filters.skill}>
            <option value="">Any skill</option>
            {skills.map((item) => (
              <option key={item.id} value={item.name}>
                {item.name}
              </option>
            ))}
          </SelectField>
        </label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
          Country
          <SelectField name="country" defaultValue={filters.country}>
            <option value="">Any country</option>
            <option value="UAE">United Arab Emirates</option>
            <option value="India">India</option>
          </SelectField>
        </label>
        {filters.country !== "India" ? (
          <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
            UAE emirate
            <SelectField name="emirate" defaultValue={filters.emirate}>
              <option value="">Any emirate</option>
              {uaeEmirates.map((item) => (
                <option key={item}>{item}</option>
              ))}
            </SelectField>
          </label>
        ) : null}
        {filters.country === "India" ? (
          <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
            Indian state / UT
            <SelectField name="state" defaultValue={filters.state}>
              <option value="">Any state</option>
              {indianStates.map((item) => (
                <option key={item}>{item}</option>
              ))}
            </SelectField>
          </label>
        ) : null}
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
          Experience
          <SelectField name="experience" defaultValue={filters.experience}>
            <option value="">Any experience</option>
            {experienceOptions.map((item) => (
              <option key={item}>{item}</option>
            ))}
          </SelectField>
        </label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
          Availability
          <SelectField name="availability" defaultValue={filters.availability}>
            <option value="">Any availability</option>
            {availabilityOptions.map((item) => (
              <option key={item}>{item}</option>
            ))}
          </SelectField>
        </label>
      </div>
      <label className="mt-4 flex items-center gap-3 text-sm font-semibold text-[#342b38]">
        <input type="checkbox" name="verified" value="true" defaultChecked={filters.verified} className="h-5 w-5 accent-[#e53670]" />
        Verified profile only
      </label>
      <div className="mt-5 flex flex-wrap gap-3">
        <Button type="submit">Search</Button>
        <ButtonLink href="/employer/search" variant="secondary">
          Clear filters
        </ButtonLink>
      </div>
    </form>
  );
}
