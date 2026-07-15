export const maxCandidateSkills = 3;

export const nationalities = [
  "Indian",
  "Pakistani",
  "Bangladeshi",
  "Nepali",
  "Filipino",
  "Sri Lankan",
  "African",
  "Other",
];

export const countries = ["UAE", "India"] as const;

export const uaeEmirates = [
  "Abu Dhabi",
  "Dubai",
  "Sharjah",
  "Ajman",
  "Umm Al Quwain",
  "Ras Al Khaimah",
  "Fujairah",
];

export const indianStates = [
  "Andhra Pradesh",
  "Arunachal Pradesh",
  "Assam",
  "Bihar",
  "Chhattisgarh",
  "Goa",
  "Gujarat",
  "Haryana",
  "Himachal Pradesh",
  "Jharkhand",
  "Karnataka",
  "Kerala",
  "Madhya Pradesh",
  "Maharashtra",
  "Manipur",
  "Meghalaya",
  "Mizoram",
  "Nagaland",
  "Odisha",
  "Punjab",
  "Rajasthan",
  "Sikkim",
  "Tamil Nadu",
  "Telangana",
  "Tripura",
  "Uttar Pradesh",
  "Uttarakhand",
  "West Bengal",
  "Andaman and Nicobar Islands",
  "Chandigarh",
  "Dadra and Nagar Haveli and Daman and Diu",
  "Delhi",
  "Jammu and Kashmir",
  "Ladakh",
  "Lakshadweep",
  "Puducherry",
];

export const languages = [
  "English",
  "Malayalam",
  "Hindi",
  "Arabic",
  "Tamil",
  "Urdu",
  "Bengali",
  "Nepali",
];

export const availabilityOptions = [
  "Immediately Available",
  "Within 7 Days",
  "Within 15 Days",
  "Within 30 Days",
  "Currently Employed",
];

export const visaStatusOptions = [
  "Visit Visa",
  "Employment Visa",
  "Cancelled Visa",
  "Own Visa",
  "Spouse Visa",
  "Not Applicable",
];

export function regionsForCountry(country: string) {
  if (country === "India") return indianStates;
  if (country === "UAE") return uaeEmirates;
  return [];
}

export function normalizeCountry(value: string) {
  const trimmed = value.trim();
  if (trimmed === "United Arab Emirates") return "UAE";
  if (trimmed === "UAE" || trimmed === "India") return trimmed;
  return "";
}
