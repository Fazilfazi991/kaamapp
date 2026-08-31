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

export function validateCurrentResidence(countryValue: string, regionValue: string) {
  const country = normalizeCountry(countryValue);
  const region = regionValue.trim();
  if (country !== "UAE" && country !== "India") return { ok: false as const, error: "Please select your current residence country." };
  if (!regionsForCountry(country).includes(region)) {
    return {
      ok: false as const,
      error: country === "India" ? "Please select your current Indian state." : "Please select your current UAE emirate.",
    };
  }
  return { ok: true as const, value: { country, region } };
}

export function validatePreferredWorkLocation(countryValue: string, regionValue: string) {
  const country = normalizeCountry(countryValue);
  const region = regionValue.trim();
  const allowed = ["UAE", "Saudi Arabia", "Qatar", "Oman", "Bahrain", "Kuwait"];
  if (!allowed.includes(country)) return { ok: false as const, error: "Please select a preferred GCC work country." };
  if (country === "UAE" && !regionsForCountry("UAE").includes(region)) {
    return { ok: false as const, error: "Please select your preferred UAE emirate." };
  }
  return { ok: true as const, value: { country, region: country === "UAE" ? region : null } };
}

export function isValidInternationalMobile(value: string) {
  const compact = value.replace(/[\s().-]/g, "");
  return /^\+[1-9]\d{6,14}$/.test(compact);
}

export function normalizeInternationalMobile(value: string) {
  return value.replace(/[\s().-]/g, "");
}
