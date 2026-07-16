import { maxCandidateSkills, normalizeCountry, regionsForCountry } from "./constants";

export function validateSkillIds(values: string[]) {
  const selected = values.map((value) => value.trim()).filter(Boolean);
  const unique = [...new Set(selected)];
  if (selected.length !== unique.length) {
    return { ok: false as const, error: "Duplicate skills are not allowed." };
  }
  if (unique.length < 1) {
    return { ok: false as const, error: "Select at least one skill." };
  }
  if (unique.length > maxCandidateSkills) {
    return {
      ok: false as const,
      error: `You can select a maximum of ${maxCandidateSkills} skills.`,
    };
  }
  return { ok: true as const, value: unique };
}

export function validateLocationSelection(countryValue: string, regionValue: string) {
  const country = normalizeCountry(countryValue);
  const region = regionValue.trim();
  if (!country) {
    return { ok: false as const, error: "Select a country." };
  }
  if (!regionsForCountry(country).includes(region)) {
    return {
      ok: false as const,
      error:
        country === "India"
          ? "Select a valid Indian state."
          : "Select a valid UAE emirate.",
    };
  }
  return { ok: true as const, value: { country, region } };
}
