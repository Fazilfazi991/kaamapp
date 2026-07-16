import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireRole } from "@/lib/auth/session";
import { secureDocumentPreviewKind } from "@/components/documents/preview-kind";
import { buildDocumentCards, fieldForDocument } from "@/features/candidate/documents/status";
import type {
  CandidateDocumentsRow,
  CandidateDocumentType,
  DocumentVersionRow,
} from "@/features/candidate/documents/types";

const DOCUMENT_SELECT = `
  id,
  candidate_id,
  passport_file_url,
  visa_file_url,
  passport_number,
  passport_issue_date,
  passport_expiry_date,
  country_of_issue,
  full_name,
  nationality,
  gender,
  dob,
  place_of_birth,
  visa_number,
  visa_type,
  occupation,
  sponsor,
  uid_number,
  emirates_id,
  visa_issue_date,
  visa_expiry_date,
  passport_verified,
  visa_verified,
  ocr_completed,
  passport_status,
  visa_status,
  passport_uploaded_at,
  visa_uploaded_at,
  passport_verified_at,
  visa_verified_at,
  passport_version,
  visa_version,
  passport_is_active,
  visa_is_active,
  passport_archived,
  visa_archived,
  updated_at
`;

export async function loadCandidateDocuments() {
  const account = await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("candidate_documents")
    .select(DOCUMENT_SELECT)
    .eq("candidate_id", account.userId)
    .maybeSingle<CandidateDocumentsRow>();

  if (error) {
    console.warn("[CandidateDocuments] load failed", {
      code: error.code,
      message: error.message,
    });
  }

  return {
    row: error ? null : data,
    cards: buildDocumentCards(error ? null : data),
    loadError: error?.code ?? null,
  };
}

export async function loadCandidateDocumentDetails(type: CandidateDocumentType) {
  const { row, loadError } = await loadCandidateDocuments();
  const supabase = await createServerSupabaseClient();
  const account = await requireRole("candidate");
  const { data: versions } = await supabase
    .from("candidate_document_versions")
    .select("id,candidate_document_id,candidate_id,document_type,file_path,version_number,status,is_active,extracted_details,created_at")
    .eq("candidate_id", account.userId)
    .eq("document_type", type)
    .order("created_at", { ascending: false })
    .returns<DocumentVersionRow[]>();

  const fileField = fieldForDocument(type, "file") as keyof CandidateDocumentsRow;
  const filePath = String(row?.[fileField] ?? "");
  return {
    row,
    loadError,
    versions: versions ?? [],
    hasFile: Boolean(filePath.trim()),
    previewKind: secureDocumentPreviewKind(filePath),
  };
}

export async function getCandidateDocumentFilePath(type: CandidateDocumentType) {
  const account = await requireRole("candidate");
  const supabase = await createServerSupabaseClient();
  const fileField = fieldForDocument(type, "file");
  const { data, error } = await supabase
    .from("candidate_documents")
    .select(fileField)
    .eq("candidate_id", account.userId)
    .maybeSingle<Record<string, string | null>>();

  if (error) return null;
  return data?.[fileField] ?? null;
}
