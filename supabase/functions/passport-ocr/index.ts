import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type OcrRequest = {
  bucket?: string;
  path?: string;
  document_type?: string;
  file_name?: string;
};

type ValidationDocumentType = "passport_front" | "passport_back" | "visa";

// Azure can report one required field below its otherwise reliable extraction score
// on a clear scan. Keep the gate conservative while avoiding false rejections.
const PASSPORT_MIN_FIELD_CONFIDENCE = 0.55;

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
  const validationType = validationTypeFor(documentType);
  if (!validationType) {
    return json({ success: false, error: "Unsupported identity document type" }, 400);
  }
  const expectedFolder = validationType === "passport_back" ? "passport-back" : validationType === "passport_front" ? "passport" : "visa";
  if (!path.startsWith(`${user.id}/candidate-documents/${expectedFolder}/`)) {
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
  const basicRejection = basicFileRejection(bytes, path, fileData.type);
  if (basicRejection) return await persistAndRespond(adminClient, user.id, validationType, bucket, path, bytes, {
    status: "rejected", reasons: [basicRejection], quality: {}, data: {}, confidence: 0,
  });

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
  const confidence = confidenceFor(fields);
  const reasons = validationReasons(validationType, normalized, confidence, result);
  const quality = qualityFor(result);
  const status = reasons.length === 0 ? "accepted" : "rejected";

  console.log(`passport-ocr: validation user=${user.id} type=${validationType} status=${status} reasons=${reasons.length}`);

  return await persistAndRespond(adminClient, user.id, validationType, bucket, path, bytes, {
    status, reasons, quality, data: normalized, confidence: overallConfidence(confidence),
  });
});

function validationTypeFor(value: string): ValidationDocumentType | undefined {
  if (value === "passport" || value === "passport-front") return "passport_front";
  if (value === "passport-back") return "passport_back";
  if (value === "visa") return "visa";
  return undefined;
}

function basicFileRejection(bytes: ArrayBuffer, path: string, contentType: string): string | undefined {
  const data = new Uint8Array(bytes);
  if (data.byteLength === 0) return "empty_file";
  if (data.byteLength > 10 * 1024 * 1024) return "file_too_large";
  const image = startsWith(data, [0xff, 0xd8, 0xff]) || startsWith(data, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const pdf = startsWith(data, [0x25, 0x50, 0x44, 0x46, 0x2d]);
  const allowedName = /\.(jpe?g|png|pdf)$/i.test(path);
  if (!allowedName || (!image && !pdf)) return "unsupported_or_mismatched_file";
  if (contentType && !(contentType.startsWith("image/") || contentType === "application/pdf")) return "mismatched_content_type";
  return undefined;
}

function startsWith(bytes: Uint8Array, signature: number[]): boolean {
  return bytes.length >= signature.length && signature.every((value, index) => bytes[index] === value);
}

function validationReasons(type: ValidationDocumentType, data: NormalizedPassport, confidence: Record<string, number>, result: Record<string, unknown>): string[] {
  const reasons: string[] = [];
  const content = String(asRecord(result.analyzeResult).content ?? "").replace(/\s/g, "");
  const document = firstDocument(result);
  const detected = String(document.docType ?? document.documentType ?? "").toLowerCase();
  if (!detected.includes("passport") && type !== "visa") {
    reasons.push("not_a_passport_page");
  }
  if (type === "passport_front") {
    if (!data.full_name || !data.passport_number || !data.nationality || !data.date_of_birth || !data.expiry_date) reasons.push("required_passport_fields_missing");
    if (!data.mrz_text || !/^P</m.test(data.mrz_text.replace(/\s/g, ""))) reasons.push("mrz_not_detected");
    if (overallConfidence(confidence) < PASSPORT_MIN_FIELD_CONFIDENCE) reasons.push("document_confidence_too_low");
  } else if (type === "passport_back") {
    if (content.length < 20) reasons.push("passport_back_not_readable");
  } else if (content.length < 20) {
    reasons.push("visa_not_readable");
  }
  return [...new Set(reasons)];
}

function firstDocument(result: Record<string, unknown>): Record<string, unknown> {
  const documents = asRecord(result.analyzeResult).documents;
  return Array.isArray(documents) ? asRecord(documents[0]) : {};
}

function qualityFor(result: Record<string, unknown>): Record<string, unknown> {
  const pages = asRecord(result.analyzeResult).pages;
  const page = Array.isArray(pages) ? asRecord(pages[0]) : {};
  return compact({ page_width: Number(page.width) || undefined, page_height: Number(page.height) || undefined, unit: typeof page.unit === "string" ? page.unit : undefined });
}

function overallConfidence(confidence: Record<string, number>): number {
  const scores = Object.values(confidence).filter((value) => Number.isFinite(value));
  return scores.length ? Math.min(...scores) : 0;
}

async function persistAndRespond(
  client: ReturnType<typeof createClient>, candidateId: string, documentType: ValidationDocumentType,
  bucket: string, path: string, bytes: ArrayBuffer,
  result: { status: "accepted" | "rejected"; reasons: string[]; quality: Record<string, unknown>; data: NormalizedPassport; confidence: number },
): Promise<Response> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  const fileHash = [...new Uint8Array(digest)].map((value) => value.toString(16).padStart(2, "0")).join("");
  const { data, error } = await client.from("candidate_document_validations").upsert({
    candidate_id: candidateId, document_type: documentType, storage_bucket: bucket, file_path: path, file_hash: fileHash,
    status: result.status, detected_document_type: documentType, confidence: result.confidence, quality: result.quality,
    extracted_data: result.data, rejection_reasons: result.reasons, provider: "azure_document_intelligence",
    provider_version: "prebuilt-idDocument:2024-11-30", validated_at: new Date().toISOString(),
    expires_at: new Date(Date.now() + 30 * 60 * 1000).toISOString(), consumed_at: null,
  }, { onConflict: "candidate_id,file_hash,document_type" }).select("id,status,expires_at").single();
  if (error || !data) {
    console.error(`passport-ocr: validation persistence failed ${error?.message ?? "unknown"}`);
    return json({ success: false, error: "Validation service is temporarily unavailable" }, 503);
  }
  return json({ success: result.status === "accepted", document_type: documentType, data: result.data,
    confidence: { overall: result.confidence }, validation: { id: data.id, status: data.status, expires_at: data.expires_at, reasons: result.reasons, quality: result.quality } }, result.status === "accepted" ? 200 : 422);
}

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
