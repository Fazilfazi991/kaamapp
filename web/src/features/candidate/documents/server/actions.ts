"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireRole } from "@/lib/auth/session";
import { routes } from "@/config/routes";
import { mapPassportOcrResponse } from "@/features/candidate/documents/ocr";
import {
  buildPrivateDocumentPath,
  cleanText,
  omitEmpty,
  validateDocumentFile,
  validatePassportReview,
} from "@/features/candidate/documents/validation";
import type {
  CandidateDocumentsRow,
  CandidateDocumentType,
  PassportReviewValues,
} from "@/features/candidate/documents/types";

function safeError(message: string): never {
  throw new Error(message);
}

function formText(formData: FormData, key: string) {
  return String(formData.get(key) ?? "").trim();
}

async function candidateClient() {
  const account = await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase
    .from("candidate_profiles")
    .upsert({ id: account.userId }, { onConflict: "id" });
  if (error) safeError("Could not initialize your candidate profile.");
  return { account, supabase };
}

async function loadExistingDocument(candidateId: string) {
  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("candidate_documents")
    .select("id,passport_file_url,visa_file_url,passport_version,visa_version,passport_expiry_date,visa_expiry_date")
    .eq("candidate_id", candidateId)
    .maybeSingle<Pick<
      CandidateDocumentsRow,
      | "id"
      | "passport_file_url"
      | "visa_file_url"
      | "passport_version"
      | "visa_version"
      | "passport_expiry_date"
      | "visa_expiry_date"
    >>();
  return data;
}

function ocrFunctionName() {
  return (
    process.env.OCR_EDGE_FUNCTION ??
    process.env.NEXT_PUBLIC_OCR_EDGE_FUNCTION ??
    "passport-ocr"
  ).trim();
}

async function saveVersion({
  candidateDocumentId,
  candidateId,
  documentType,
  filePath,
  version,
  extractedDetails,
}: {
  candidateDocumentId: string | null;
  candidateId: string;
  documentType: CandidateDocumentType;
  filePath: string;
  version: number;
  extractedDetails: Record<string, unknown>;
}) {
  const supabase = await createServerSupabaseClient();
  await supabase
    .from("candidate_document_versions")
    .update({ is_active: false })
    .eq("candidate_id", candidateId)
    .eq("document_type", documentType);
  const { error } = await supabase.from("candidate_document_versions").insert({
    candidate_document_id: candidateDocumentId,
    candidate_id: candidateId,
    document_type: documentType,
    file_path: filePath,
    version_number: version,
    status: "pending_verification",
    is_active: true,
    extracted_details: extractedDetails,
  });
  if (error) {
    console.warn("[CandidateDocuments] version history failed", {
      code: error.code,
      documentType,
    });
  }
}

async function uploadDocument(formData: FormData, documentType: CandidateDocumentType) {
  const file = formData.get("documentFile");
  if (!(file instanceof File)) safeError("Choose a document file first.");
  const validation = validateDocumentFile({
    type: documentType,
    mimeType: file.type,
    size: file.size,
  });
  if (!validation.ok) safeError(validation.error);

  const { account, supabase } = await candidateClient();
  const existing = await loadExistingDocument(account.userId);
  const path = buildPrivateDocumentPath({
    userId: account.userId,
    documentType,
    extension: validation.extension,
  });
  const { error: uploadError } = await supabase.storage
    .from("kaam-private")
    .upload(path, await file.arrayBuffer(), {
      contentType: file.type,
      upsert: false,
    });
  if (uploadError) {
    console.error("[candidate_document_upload]", {
      code: uploadError.message,
      documentType,
      bucket: "kaam-private",
      statusCode: uploadError.statusCode,
    });
    safeError("Could not upload the document securely.");
  }

  const now = new Date().toISOString();
  const isPassport = documentType === "passport";
  const version = (isPassport ? existing?.passport_version : existing?.visa_version) ?? 0;
  const nextVersion = version + 1;

  const baseValues = isPassport
    ? {
        passport_file_url: path,
        passport_status: "pending_verification",
        passport_uploaded_at: now,
        passport_verified_at: null,
        passport_version: nextVersion,
        passport_is_active: true,
        passport_archived: Boolean(existing?.passport_file_url),
        passport_verified: false,
        ocr_completed: false,
      }
    : {
        visa_file_url: path,
        visa_status: "pending_verification",
        visa_uploaded_at: now,
        visa_verified_at: null,
        visa_version: nextVersion,
        visa_is_active: true,
        visa_archived: Boolean(existing?.visa_file_url),
        visa_verified: false,
        ocr_completed: false,
      };

  let extractedDetails: Record<string, unknown> = {};
  let ocrResult = "manual";
  if (isPassport) {
    const functionName = ocrFunctionName();
    try {
      const response = await supabase.functions.invoke(functionName, {
        body: {
          document_type: documentType,
          bucket: "kaam-private",
          path,
          file_name: file.name,
        },
      });
      if (response.error) throw response.error;
      const mapped = mapPassportOcrResponse(response.data);
      if (!mapped.hasAnyData) throw new Error("OCR returned no readable passport data.");
      extractedDetails = {
        full_name: mapped.full_name,
        passport_number: mapped.passport_number,
        nationality: mapped.nationality,
        dob: mapped.dob,
        gender: mapped.gender,
        passport_issue_date: mapped.passport_issue_date,
        passport_expiry_date: mapped.passport_expiry_date,
        place_of_birth: mapped.place_of_birth,
        country_of_issue: mapped.country_of_issue,
        ocr_completed: true,
      };
      Object.assign(baseValues, extractedDetails, { ocr_completed: true });
      ocrResult = "success";
    } catch (error) {
      console.warn("[CandidateDocuments] OCR fallback", {
        type: error instanceof Error ? error.name : "unknown",
        function: functionName,
      });
    }
  }

  const { data: saved, error: saveError } = await supabase
    .from("candidate_documents")
    .upsert(
      {
        candidate_id: account.userId,
        ...baseValues,
      },
      { onConflict: "candidate_id" },
    )
    .select("id")
    .single<{ id: string }>();
  if (saveError) {
    console.error("[candidate_document_save]", {
      code: saveError.code,
      message: saveError.message,
      details: saveError.details,
      hint: saveError.hint,
      documentType,
    });
    safeError("Could not save document details.");
  }

  await saveVersion({
    candidateDocumentId: saved.id,
    candidateId: account.userId,
    documentType,
    filePath: path,
    version: nextVersion,
    extractedDetails,
  });

  revalidatePath(routes.candidateDocuments);
  revalidatePath(routes.candidateDashboard);
  return { ocrResult };
}

export async function uploadPassportDocument(formData: FormData) {
  const result = await uploadDocument(formData, "passport");
  redirect(`${routes.candidateDocuments}/passport/review?ocr=${result.ocrResult}`);
}

export type PassportSideUploadResult = {
  ok: boolean;
  error?: string;
  path?: string;
  fields?: Record<string, string>;
};

/** Canonical passport validation step. This intentionally does not write candidate_documents. */
export async function uploadPassportSide(formData: FormData): Promise<PassportSideUploadResult> {
  const file = formData.get("documentFile");
  const side = String(formData.get("side") ?? "");
  if (!(file instanceof File) || !["front", "back"].includes(side)) {
    return { ok: false, error: "Choose a passport image first." };
  }
  const validation = validateDocumentFile({ type: "passport", mimeType: file.type, size: file.size });
  if (!validation.ok) return { ok: false, error: validation.error };

  const { account, supabase } = await candidateClient();
  const documentType = side === "front" ? "passport" : "passport-back";
  const path = `${account.userId}/candidate-documents/${documentType}/${Date.now()}_${documentType}.${validation.extension}`;
  const { error: uploadError } = await supabase.storage.from("kaam-private").upload(path, await file.arrayBuffer(), {
    contentType: file.type,
    upsert: false,
  });
  if (uploadError) {
    console.error("[candidate_passport_side_upload]", { code: uploadError.message, statusCode: uploadError.statusCode, side });
    return { ok: false, error: "We couldn’t upload this image. Please try again." };
  }

  const response = await supabase.functions.invoke(ocrFunctionName(), {
    body: { document_type: side === "front" ? "passport" : "passport-back", bucket: "kaam-private", path, file_name: file.name },
  });
  const data = response.data as Record<string, unknown> | null;
  const accepted = data?.success === true && (data.validation as Record<string, unknown> | undefined)?.status === "accepted";
  if (response.error || !accepted) {
    console.warn("[candidate_passport_side_validation]", { side, error: response.error?.name ?? null });
    return { ok: false, error: side === "front" ? "This passport identity page could not be validated. Use a clear passport information page." : "This passport back could not be validated. Use a clear, distinct back image." };
  }
  const mapped = side === "front" ? mapPassportOcrResponse(data) : null;
  return {
    ok: true,
    path,
    fields: mapped ? {
      full_name: mapped.full_name ?? "", passport_number: mapped.passport_number ?? "", nationality: mapped.nationality ?? "",
      dob: mapped.dob ?? "", gender: mapped.gender ?? "", passport_issue_date: mapped.passport_issue_date ?? "",
      passport_expiry_date: mapped.passport_expiry_date ?? "", place_of_birth: mapped.place_of_birth ?? "", country_of_issue: mapped.country_of_issue ?? "",
    } : {},
  };
}

export async function submitPassportIdentityDocuments(formData: FormData): Promise<{ ok: boolean; error?: string }> {
  const frontPath = formText(formData, "frontPath");
  const backPath = formText(formData, "backPath");
  if (!frontPath || !backPath) return { ok: false, error: "Validate both passport front and back before submitting." };
  const fields = Object.fromEntries(["full_name", "passport_number", "nationality", "dob", "gender", "passport_issue_date", "passport_expiry_date", "place_of_birth", "country_of_issue"].map((key) => [key, formText(formData, key)]));
  const required = ["full_name", "passport_number", "nationality", "dob", "passport_expiry_date", "country_of_issue"];
  if (required.some((key) => !fields[key])) return { ok: false, error: "Validated passport details are incomplete. Replace the passport front with a clearer image." };
  const { supabase } = await candidateClient();
  const { error } = await supabase.rpc("submit_candidate_identity_documents", {
    p_document_type: "passport", p_front_path: frontPath, p_back_path: backPath, p_fields: fields, p_profile_fields: {}, p_candidate_fields: {},
  });
  if (error) {
    console.error("[candidate_passport_submit]", { code: error.code, message: error.message, details: error.details, hint: error.hint });
    return { ok: false, error: error.message.includes("cannot use the same") ? "Passport front and back must be different images." : "We couldn’t submit your passport. Please review both images and try again." };
  }
  revalidatePath(routes.candidateDocuments);
  revalidatePath(routes.candidateDashboard);
  return { ok: true };
}

export async function uploadVisaDocument(formData: FormData) {
  await uploadDocument(formData, "visa");
  redirect(`${routes.candidateDocuments}/visa`);
}

export async function savePassportReview(formData: FormData) {
  const values: PassportReviewValues = {
    full_name: cleanText(formData.get("full_name")),
    passport_number: cleanText(formData.get("passport_number")),
    nationality: cleanText(formData.get("nationality")),
    dob: cleanText(formData.get("dob")),
    gender: cleanText(formData.get("gender")),
    passport_issue_date: cleanText(formData.get("passport_issue_date")),
    passport_expiry_date: cleanText(formData.get("passport_expiry_date")),
    place_of_birth: cleanText(formData.get("place_of_birth")),
    country_of_issue: cleanText(formData.get("country_of_issue")),
  };
  const validation = validatePassportReview(values);
  if (!validation.ok) safeError(validation.error);

  const { account, supabase } = await candidateClient();
  const submit = formData.get("intent") === "submit";
  const payload = omitEmpty({
    ...validation.value,
    ocr_completed: true,
    passport_status: submit ? "pending_verification" : "pending_verification",
    passport_verified: false,
  });

  const { error } = await supabase
    .from("candidate_documents")
    .update(payload)
    .eq("candidate_id", account.userId);
  if (error) safeError("Could not save passport details.");

  const { data: activeVersion } = await supabase
    .from("candidate_document_versions")
    .select("id,extracted_details")
    .eq("candidate_id", account.userId)
    .eq("document_type", "passport")
    .eq("is_active", true)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle<{ id: string; extracted_details: Record<string, unknown> | null }>();
  if (activeVersion?.id) {
    await supabase
      .from("candidate_document_versions")
      .update({
        extracted_details: {
          ...(activeVersion.extracted_details ?? {}),
          ...validation.value,
          ocr_completed: true,
        },
      })
      .eq("id", activeVersion.id);
  }

  revalidatePath(routes.candidateDocuments);
  revalidatePath(`${routes.candidateDocuments}/passport`);
  revalidatePath(`${routes.candidateDocuments}/passport/review`);
  redirect(routes.candidateDocuments);
}
