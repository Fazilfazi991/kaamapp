import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireRole } from "@/lib/auth/session";
import type { EmployerCompany, VerificationDocumentRow } from "@/features/employer/types";

export async function loadEmployerCompanyBundle() {
  const account = await requireRole("employer");
  const supabase = await createServerSupabaseClient();
  const { data: company } = await supabase
    .from("employer_companies")
    .select("*")
    .eq("owner_id", account.userId)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle<EmployerCompany>();
  const { data: documents } = await supabase
    .from("verification_documents")
    .select("id,owner_id,company_id,document_type,bucket_id,file_path,status,created_at,updated_at")
    .eq("owner_id", account.userId)
    .order("created_at", { ascending: false })
    .returns<VerificationDocumentRow[]>();
  return { account, company, documents: documents ?? [] };
}

export async function getOwnedVerificationDocument(documentId: string) {
  const account = await requireRole("employer");
  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("verification_documents")
    .select("id,owner_id,company_id,document_type,bucket_id,file_path,status,created_at,updated_at")
    .eq("id", documentId)
    .eq("owner_id", account.userId)
    .maybeSingle<VerificationDocumentRow>();
  return data;
}
