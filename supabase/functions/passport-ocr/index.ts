import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type OcrRequest = {
  bucket?: string;
  path?: string;
  document_type?: string;
  file_name?: string;
};

type NormalizedPassport = {
  full_name?: string;
  first_name?: string;
  last_name?: string;
  passport_number?: string;
  nationality?: string;
  date_of_birth?: string;
  gender?: string;
  issue_date?: string;
  expiry_date?: string;
  place_of_birth?: string;
  country_of_issue?: string;
  mrz_text?: string;
  raw_text?: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ success: false, error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const supabaseUrl = requiredEnv("SUPABASE_URL");
  const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const azureEndpoint = requiredEnv("AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT").replace(/\/+$/, "");
  const azureKey = requiredEnv("AZURE_DOCUMENT_INTELLIGENCE_KEY");

  const userClient = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData?.user;
  if (userError || !user) {
    return json({ success: false, error: "Authentication required" }, 401);
  }

  let body: OcrRequest;
  try {
    body = await req.json();
  } catch {
    return json({ success: false, error: "Invalid JSON request" }, 400);
  }

  const bucket = body.bucket?.trim() ?? "";
  const path = body.path?.trim() ?? "";
  const documentType = body.document_type?.trim() ?? "";
  if (bucket !== "kaam-private") {
    return json({ success: false, error: "Invalid storage bucket" }, 400);
  }
  if (documentType !== "passport") {
    return json({ success: false, error: "Only passport OCR is supported" }, 400);
  }
  if (!path.startsWith(`${user.id}/candidate-documents/passport/`)) {
    return json({ success: false, error: "Document path is not owned by this user" }, 403);
  }

  console.log(`passport-ocr: request user=${user.id} file=${safeFileName(body.file_name)} path=${safePath(path)}`);

  const { data: fileData, error: downloadError } = await adminClient.storage
    .from(bucket)
    .download(path);
  if (downloadError || !fileData) {
    console.error(`passport-ocr: storage download failed user=${user.id} path=${safePath(path)} error=${downloadError?.message}`);
    return json({ success: false, error: "Could not read uploaded passport" }, 404);
  }

  const bytes = await fileData.arrayBuffer();
  if (bytes.byteLength === 0) {
    return json({ success: false, error: "Uploaded passport file is empty" }, 400);
  }

  const analyzeUrl =
    `${azureEndpoint}/documentintelligence/documentModels/prebuilt-idDocument:analyze?api-version=2024-11-30`;
  const start = await fetch(analyzeUrl, {
    method: "POST",
    headers: {
      "Ocp-Apim-Subscription-Key": azureKey,
      "Content-Type": fileData.type || contentTypeFor(path),
    },
    body: bytes,
  });

  if (start.status !== 202) {
    const detail = await safeText(start);
    console.error(`passport-ocr: azure analyze failed status=${start.status} detail=${detail.slice(0, 180)}`);
    return json({ success: false, error: "Azure OCR request failed" }, 502);
  }

  const operationLocation = start.headers.get("operation-location");
  if (!operationLocation) {
    return json({ success: false, error: "Azure OCR operation was not returned" }, 502);
  }

  const result = await pollAzure(operationLocation, azureKey);
  const fields = extractDocumentFields(result);
  const normalized = normalizePassport(fields, result);
  const warnings = warningsFor(normalized);

  console.log(`passport-ocr: success user=${user.id} keys=${Object.keys(normalized).join(",")} warnings=${warnings.length}`);

  return json({
    success: true,
    document_type: "passport",
    data: normalized,
    confidence: confidenceFor(fields),
    warnings,
  });
});

async function pollAzure(operationLocation: string, key: string): Promise<Record<string, unknown>> {
  const started = Date.now();
  while (Date.now() - started < 30_000) {
    await new Promise((resolve) => setTimeout(resolve, 1200));
    const response = await fetch(operationLocation, {
      headers: { "Ocp-Apim-Subscription-Key": key },
    });
    if (!response.ok) {
      throw new Error(`Azure polling failed with ${response.status}`);
    }
    const data = await response.json();
    const status = String(data.status ?? "").toLowerCase();
    if (status === "succeeded") return data;
    if (status === "failed" || status === "canceled") {
      throw new Error(`Azure OCR ${status}`);
    }
  }
  throw new Error("Azure OCR timed out");
}

function extractDocumentFields(result: Record<string, unknown>): Record<string, unknown> {
  const analyzeResult = asRecord(result.analyzeResult);
  const documents = Array.isArray(analyzeResult.documents) ? analyzeResult.documents : [];
  const first = asRecord(documents[0]);
  return asRecord(first.fields);
}

function normalizePassport(fields: Record<string, unknown>, result: Record<string, unknown>): NormalizedPassport {
  const firstName = fieldString(fields, ["FirstName", "GivenNames", "GivenName", "firstName", "given_names"]);
  const lastName = fieldString(fields, ["LastName", "Surname", "lastName", "surname"]);
  const joinedName = [firstName, lastName].filter(Boolean).join(" ").trim() || undefined;
  const fullName =
    fieldString(fields, ["FullName", "Name", "DocumentName", "full_name", "holder_name"]) ??
    joinedName;
  const rawText = String(asRecord(result.analyzeResult).content ?? "");
  const mrzText = extractMrz(rawText);
  const mrz = parseMrz(mrzText);

  return compact({
    full_name: fullName ?? mrz.full_name,
    first_name: firstName ?? mrz.first_name,
    last_name: lastName ?? mrz.last_name,
    passport_number: fieldString(fields, ["DocumentNumber", "PassportNumber", "document_number"]) ?? mrz.passport_number,
    nationality: fieldString(fields, ["Nationality", "NationalityCountryRegion", "nationality"]) ?? mrz.nationality,
    date_of_birth: fieldDate(fields, ["DateOfBirth", "BirthDate", "date_of_birth"]) ?? mrz.date_of_birth,
    gender: fieldString(fields, ["Sex", "Gender", "sex", "gender"]) ?? mrz.gender,
    issue_date: fieldDate(fields, ["DateOfIssue", "IssueDate", "date_of_issue"]),
    expiry_date: fieldDate(fields, ["DateOfExpiration", "DateOfExpiry", "ExpiryDate", "expiration_date"]) ?? mrz.expiry_date,
    place_of_birth: fieldString(fields, ["PlaceOfBirth", "BirthPlace", "place_of_birth"]),
    country_of_issue: fieldString(fields, ["IssuingCountry", "CountryRegion", "country_of_issue"]) ?? mrz.country_of_issue,
    mrz_text: mrzText,
    raw_text: rawText,
  });
}

function confidenceFor(fields: Record<string, unknown>): Record<string, number> {
  const map: Record<string, number> = {};
  const pairs: Record<string, string[]> = {
    full_name: ["FullName", "Name", "DocumentName"],
    passport_number: ["DocumentNumber", "PassportNumber"],
    nationality: ["Nationality", "NationalityCountryRegion"],
    date_of_birth: ["DateOfBirth", "BirthDate"],
    expiry_date: ["DateOfExpiration", "DateOfExpiry", "ExpiryDate"],
  };
  for (const [target, keys] of Object.entries(pairs)) {
    for (const key of keys) {
      const field = asRecord(fields[key]);
      const confidence = Number(field.confidence);
      if (!Number.isNaN(confidence)) {
        map[target] = confidence;
        break;
      }
    }
  }
  return map;
}

function warningsFor(data: NormalizedPassport): string[] {
  const warnings: string[] = [];
  if (!data.passport_number) warnings.push("passport_number_missing");
  if (!data.full_name) warnings.push("full_name_missing");
  if (!data.expiry_date) warnings.push("expiry_date_missing");
  const expiry = data.expiry_date ? Date.parse(data.expiry_date) : Number.NaN;
  if (!Number.isNaN(expiry) && expiry < Date.now()) warnings.push("passport_expired");
  return warnings;
}

function fieldString(fields: Record<string, unknown>, keys: string[]): string | undefined {
  for (const key of keys) {
    const field = asRecord(fields[key]);
    const value = field.valueString ?? field.content ?? field.valueCountryRegion;
    if (typeof value === "string" && value.trim()) return clean(value);
  }
  return undefined;
}

function fieldDate(fields: Record<string, unknown>, keys: string[]): string | undefined {
  for (const key of keys) {
    const field = asRecord(fields[key]);
    const value = field.valueDate ?? field.valueString ?? field.content;
    if (typeof value === "string" && value.trim()) return normalizeDate(value);
  }
  return undefined;
}

function parseMrz(mrz?: string): NormalizedPassport {
  if (!mrz) return {};
  const lines = mrz.split(/\r?\n/).map((line) => line.trim().replace(/\s/g, "")).filter((line) => line.length >= 30);
  const start = lines.findIndex((line) => line.startsWith("P<"));
  if (start < 0 || lines.length <= start + 1) return {};
  const line1 = lines[start].padEnd(44, "<").slice(0, 44);
  const line2 = lines[start + 1].padEnd(44, "<").slice(0, 44);
  const country = line1.slice(2, 5).replaceAll("<", "");
  const nameParts = line1.slice(5).split("<<");
  const lastName = mrzName(nameParts[0] ?? "");
  const firstName = mrzName(nameParts[1] ?? "");
  return compact({
    full_name: [firstName, lastName].filter(Boolean).join(" "),
    first_name: firstName,
    last_name: lastName,
    passport_number: line2.slice(0, 9).replaceAll("<", ""),
    nationality: line2.slice(10, 13).replaceAll("<", ""),
    date_of_birth: mrzDate(line2.slice(13, 19), true),
    gender: line2.slice(20, 21).replaceAll("<", ""),
    expiry_date: mrzDate(line2.slice(21, 27), false),
    country_of_issue: country,
  });
}

function extractMrz(rawText: string): string | undefined {
  const lines = rawText.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  const start = lines.findIndex((line) => line.replace(/\s/g, "").startsWith("P<"));
  if (start < 0 || lines.length <= start + 1) return undefined;
  return `${lines[start]}\n${lines[start + 1]}`;
}

function mrzDate(value: string, birth: boolean): string | undefined {
  if (!/^\d{6}$/.test(value)) return undefined;
  const yy = Number(value.slice(0, 2));
  const mm = Number(value.slice(2, 4));
  const dd = Number(value.slice(4, 6));
  const now = new Date();
  let year = birth ? 1900 + yy : 2000 + yy;
  if (birth && year > now.getUTCFullYear()) year -= 100;
  if (!birth && year < now.getUTCFullYear() - 10) year += 100;
  if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return undefined;
  return `${String(year).padStart(4, "0")}-${String(mm).padStart(2, "0")}-${String(dd).padStart(2, "0")}`;
}

function mrzName(value: string): string {
  return value.split("<").filter(Boolean).map((part) => part.charAt(0) + part.slice(1).toLowerCase()).join(" ");
}

function normalizeDate(value: string): string {
  const parsed = new Date(value);
  if (!Number.isNaN(parsed.getTime())) return parsed.toISOString().slice(0, 10);
  const parts = value.replace(/[./]/g, "-").split("-");
  if (parts.length === 3 && parts[2].length === 4) {
    return `${parts[2]}-${parts[1].padStart(2, "0")}-${parts[0].padStart(2, "0")}`;
  }
  return value;
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function compact<T extends Record<string, unknown>>(value: T): T {
  return Object.fromEntries(Object.entries(value).filter(([, v]) => v !== undefined && v !== "")) as T;
}

function clean(value: string): string {
  return value.replace(/</g, " ").replace(/\s+/g, " ").trim();
}

function contentTypeFor(path: string): string {
  const lower = path.toLowerCase();
  if (lower.endsWith(".pdf")) return "application/pdf";
  if (lower.endsWith(".png")) return "image/png";
  return "image/jpeg";
}

function safePath(path: string): string {
  const parts = path.split("/");
  return parts.length > 2 ? `${parts[0]}/.../${parts.at(-1)}` : path;
}

function safeFileName(name?: string): string {
  return (name ?? "passport").replace(/[^A-Za-z0-9._-]/g, "_").slice(0, 80);
}

async function safeText(response: Response): Promise<string> {
  try {
    return await response.text();
  } catch {
    return "";
  }
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
