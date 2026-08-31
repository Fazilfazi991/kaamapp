import { normalizeCountry, uaeEmirates } from "@/features/candidate/constants";

export const employerCompanyCountries = ["UAE", "Saudi Arabia", "Qatar", "Oman", "Bahrain", "Kuwait"] as const;
export type EmployerCompanyCountry = (typeof employerCompanyCountries)[number];

export function normalizeEmployerCompanyCountry(value: string): EmployerCompanyCountry | "" {
  const country = normalizeCountry(value);
  return employerCompanyCountries.includes(country as EmployerCompanyCountry)
    ? country as EmployerCompanyCountry
    : "";
}

export function employerCompanyLocationParts(countryValue?: string | null, cityValue?: string | null, officeAreaValue?: string | null) {
  const country = normalizeEmployerCompanyCountry(countryValue ?? "");
  if (!country) return [];
  const city = cityValue?.trim() ?? "";
  const officeArea = officeAreaValue?.trim() ?? "";
  return [officeArea || null, country === "UAE" && uaeEmirates.includes(city) ? city : null, country].filter(Boolean) as string[];
}

export const companySizeOptions = ["1-10", "11-50", "51-200", "201-500", "500+"];
export const employerIndustryOptions = [
  "Facilities",
  "Hospitality",
  "Retail",
  "Construction",
  "Logistics",
  "Cleaning",
  "Security",
  "Domestic Work",
  "Other",
];

export function cleanText(value: FormDataEntryValue | string | null | undefined) {
  return String(value ?? "").replace(/\s+/g, " ").trim();
}

export function validateCompanyInfo(values: {
  companyName: string;
  industry: string;
  companySize: string;
  tradeLicenseNumber: string;
}) {
  if (values.companyName.length < 2) return { ok: false as const, error: "Company name is required." };
  if (!employerIndustryOptions.includes(values.industry)) return { ok: false as const, error: "Select a valid industry." };
  if (!companySizeOptions.includes(values.companySize)) return { ok: false as const, error: "Select a valid company size." };
  return { ok: true as const };
}

export function validateEmployerLocation(countryValue: string, regionValue: string, officeArea: string) {
  const country = normalizeEmployerCompanyCountry(countryValue);
  const region = regionValue.trim();
  if (!country) return { ok: false as const, error: "Select a supported GCC country." };
  if (country === "UAE" && !uaeEmirates.includes(region)) {
    return { ok: false as const, error: "Select a valid UAE emirate." };
  }
  return { ok: true as const, value: { country, city: country === "UAE" ? region : null, officeArea: officeArea.trim() || null } };
}

export function validateEmployerContact(values: { contactPerson: string; contactRole: string; website: string }) {
  if (values.contactPerson.length < 2) return { ok: false as const, error: "Contact person name is required." };
  if (!values.contactRole.trim()) return { ok: false as const, error: "Contact person role is required." };
  if (values.website && !/^https?:\/\/[^\s]+\.[^\s]+$/i.test(values.website)) {
    return { ok: false as const, error: "Website must start with http:// or https://." };
  }
  return { ok: true as const };
}

export function validatePhone(value: string) {
  if (!value.trim()) return true;
  return /^\+?[0-9 ()-]{7,20}$/.test(value);
}
