import type { PassportReviewValues } from "./types";

export type PassportExtraction = PassportReviewValues & {
  rawText?: string;
  responseKeys: string[];
  hasAnyData: boolean;
};

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function firstString(data: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const value = data[key];
    if (value === null || value === undefined) continue;
    const text = String(value).replace(/</g, " ").replace(/\s+/g, " ").trim();
    if (text) return text;
  }
  return "";
}

function parseDate(value: unknown) {
  const text = String(value ?? "").trim();
  if (!text) return "";
  if (/^\d{4}-\d{2}-\d{2}/.test(text)) {
    const iso = Date.parse(text);
    if (Number.isFinite(iso)) return new Date(iso).toISOString().slice(0, 10);
  }
  const normalized = text.replace(/[./]/g, "-");
  const parts = normalized.split("-");
  if (parts.length !== 3) return "";
  if (parts[0]?.length === 4 && Number.isFinite(Date.parse(normalized))) return normalized;
  const [day, month, year] = parts;
  const padded = `${year}-${month.padStart(2, "0")}-${day.padStart(2, "0")}`;
  return Number.isFinite(Date.parse(padded)) ? padded : "";
}

function firstDate(data: Record<string, unknown>, keys: string[]) {
  for (const key of keys) {
    const parsed = parseDate(data[key]);
    if (parsed) return parsed;
  }
  return "";
}

function parseMrz(rawText?: string) {
  if (!rawText) return {};
  const lines = rawText
    .split(/\r?\n/)
    .map((line) => line.trim().replace(/\s+/g, ""))
    .filter((line) => line.length >= 30);
  const start = lines.findIndex((line) => line.startsWith("P<"));
  if (start < 0 || !lines[start + 1]) return {};
  const line1 = lines[start].padEnd(44, "<").slice(0, 44);
  const line2 = lines[start + 1].padEnd(44, "<").slice(0, 44);
  const names = line1.slice(5).split("<<");
  const formatName = (value: string) =>
    value
      .split("<")
      .filter(Boolean)
      .map((part) => part.charAt(0) + part.slice(1).toLowerCase())
      .join(" ");
  return {
    full_name: [formatName(names[1] ?? ""), formatName(names[0] ?? "")].filter(Boolean).join(" "),
    passport_number: line2.slice(0, 9).replace(/</g, ""),
    nationality: line2.slice(10, 13).replace(/</g, ""),
    gender: line2.slice(20, 21).replace(/</g, ""),
    country_of_issue: line1.slice(2, 5).replace(/</g, ""),
  };
}

export function mapPassportOcrResponse(response: unknown): PassportExtraction {
  const root = asRecord(response);
  const data = Object.keys(asRecord(root.data)).length > 0 ? asRecord(root.data) : root;
  const rawText = firstString(data, [
    "raw_text",
    "rawText",
    "text",
    "ocr_text",
    "mrz",
    "mrz_text",
    "mrzText",
  ]);
  const mrz = parseMrz(rawText);

  const extraction = {
    full_name:
      firstString(data, ["full_name", "fullName", "name", "holder_name", "holderName"]) ||
      String(mrz.full_name ?? ""),
    passport_number:
      firstString(data, ["passport_number", "passportNumber", "document_number", "documentNumber", "number"]) ||
      String(mrz.passport_number ?? ""),
    nationality:
      firstString(data, ["nationality", "nationality_code", "nationalityCode"]) ||
      String(mrz.nationality ?? ""),
    dob: firstDate(data, ["date_of_birth", "dateOfBirth", "dob", "birth_date", "birthDate"]),
    gender: firstString(data, ["sex", "gender"]) || String(mrz.gender ?? ""),
    passport_issue_date: firstDate(data, ["issue_date", "issueDate", "date_of_issue"]),
    passport_expiry_date: firstDate(data, ["expiry_date", "expiryDate", "expiration_date", "date_of_expiry"]),
    place_of_birth: firstString(data, ["place_of_birth", "placeOfBirth", "birth_place"]),
    country_of_issue:
      firstString(data, ["country_of_issue", "countryOfIssue", "issuing_country", "issuingCountry"]) ||
      String(mrz.country_of_issue ?? ""),
  };

  return {
    ...extraction,
    rawText,
    responseKeys: Object.keys(data).sort(),
    hasAnyData: Object.values(extraction).some((value) => value.trim() !== "") || Boolean(rawText),
  };
}
