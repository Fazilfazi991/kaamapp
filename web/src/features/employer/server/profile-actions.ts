"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireRole } from "@/lib/auth/session";
import { routes } from "@/config/routes";
import { employerCompanyCompletion } from "@/features/employer/profile/completion";
import {
  cleanText,
  validateCompanyInfo,
  validateEmployerContact,
  validateEmployerLocation,
  validatePhone,
} from "@/features/employer/profile/validation";
import {
  documentTypeConfig,
  safeUploadPath,
  validateEmployerDocumentFile,
  validateEmployerLogoFile,
} from "@/features/employer/documents/validation";
import { loadEmployerCompanyBundle } from "./profile-data";

function safeError(message: string): never {
  throw new Error(message);
}

async function employerClient() {
  const account = await requireRole("employer");
  const supabase = await createServerSupabaseClient();
  return { account, supabase };
}

async function upsertCompany(values: Record<string, unknown>) {
  const { account, supabase } = await employerClient();
  await supabase.from("profiles").upsert(
    {
      id: account.userId,
      role: "employer",
      email: account.email,
      status: "active",
    },
    { onConflict: "id" },
  );
  const { data: existing } = await supabase
    .from("employer_companies")
    .select("id")
    .eq("owner_id", account.userId)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle<{ id: string }>();
  if (existing) {
    const { error } = await supabase.from("employer_companies").update(values).eq("id", existing.id).eq("owner_id", account.userId);
    if (error) safeError("Could not save company profile.");
  } else {
    const { error } = await supabase.from("employer_companies").insert({
      owner_id: account.userId,
      company_name: String(values.company_name ?? ""),
      ...values,
      status: "active",
    });
    if (error) safeError("Could not create company profile.");
  }
  revalidateEmployerPages();
}

function revalidateEmployerPages() {
  revalidatePath(routes.employerDashboard);
  revalidatePath(routes.employerProfile);
  revalidatePath(routes.employerSearch);
  revalidatePath("/employer/onboarding");
  revalidatePath("/employer/documents");
}

export async function saveCompanyInformation(formData: FormData) {
  const values = {
    companyName: cleanText(formData.get("companyName")),
    industry: cleanText(formData.get("industry")),
    companySize: cleanText(formData.get("companySize")),
    tradeLicenseNumber: cleanText(formData.get("tradeLicenseNumber")),
    description: cleanText(formData.get("description")),
  };
  const validation = validateCompanyInfo(values);
  if (!validation.ok) safeError(validation.error);
  await upsertCompany({
    company_name: values.companyName,
    trade_license_number: values.tradeLicenseNumber,
    industry: values.industry,
    company_size: values.companySize,
    description: values.description || null,
  });
  redirect(String(formData.get("next") ?? "/employer/onboarding/location"));
}

export async function saveCompanyLocation(formData: FormData) {
  const validation = validateEmployerLocation(
    cleanText(formData.get("country")),
    cleanText(formData.get("region")),
    cleanText(formData.get("officeArea")),
  );
  if (!validation.ok) safeError(validation.error);
  await upsertCompany({
    country: validation.value.country,
    city: validation.value.city,
    office_area: validation.value.officeArea,
  });
  redirect(String(formData.get("next") ?? "/employer/onboarding/contact"));
}

export async function saveCompanyContact(formData: FormData) {
  const values = {
    contactPerson: cleanText(formData.get("contactPerson")),
    contactRole: cleanText(formData.get("contactRole")),
    website: cleanText(formData.get("website")),
  };
  const phone = cleanText(formData.get("companyPhone"));
  const validation = validateEmployerContact(values);
  if (!validation.ok) safeError(validation.error);
  if (!validatePhone(phone)) safeError("Enter a valid international phone number.");
  await upsertCompany({
    contact_person: values.contactPerson,
    contact_role: values.contactRole,
    website: values.website || null,
  });
  redirect(String(formData.get("next") ?? "/employer/onboarding/documents"));
}

export async function uploadCompanyLogo(formData: FormData) {
  const file = formData.get("logo");
  if (!(file instanceof File)) safeError("Choose a logo file first.");
  const validation = validateEmployerLogoFile(file.type, file.size);
  if (!validation.ok) safeError(validation.error);
  const { account, supabase } = await employerClient();
  const path = safeUploadPath({ userId: account.userId, folder: "company-logo", fileName: file.name });
  const { error } = await supabase.storage.from("kaam-public").upload(path, await file.arrayBuffer(), {
    contentType: file.type,
    upsert: true,
  });
  if (error) safeError("Could not upload company logo.");
  const { data } = supabase.storage.from("kaam-public").getPublicUrl(path);
  await upsertCompany({ logo_url: data.publicUrl });
  redirect(routes.employerProfileEdit);
}

export async function uploadEmployerDocument(formData: FormData) {
  const documentType = cleanText(formData.get("documentType"));
  const config = documentTypeConfig(documentType);
  if (!config) safeError("Unsupported document type.");
  const file = formData.get("documentFile");
  if (!(file instanceof File)) safeError("Choose a document file first.");
  const validation = validateEmployerDocumentFile(documentType, file.type, file.size);
  if (!validation.ok) safeError(validation.error);
  const { account, company, documents } = await loadEmployerCompanyBundle();
  if (!company) safeError("Create your company profile before uploading documents.");
  const existingApproved = documents.find((document) => document.document_type === documentType && document.status === "approved");
  if (existingApproved) safeError("Approved documents cannot be silently overwritten. Contact support or upload a separate resubmission after review.");
  const supabase = await createServerSupabaseClient();
  const path = safeUploadPath({ userId: account.userId, folder: documentType, fileName: file.name });
  const { error: uploadError } = await supabase.storage.from("kaam-private").upload(path, await file.arrayBuffer(), {
    contentType: file.type,
    upsert: false,
  });
  if (uploadError) safeError("Could not upload this document securely.");
  const { error } = await supabase.from("verification_documents").insert({
    owner_id: account.userId,
    company_id: company.id,
    document_type: documentType,
    bucket_id: "kaam-private",
    file_path: path,
    status: "pending",
  });
  if (error) safeError("Could not save verification document.");
  revalidateEmployerPages();
  redirect("/employer/documents");
}

export async function submitEmployerVerification() {
  const { company, documents } = await loadEmployerCompanyBundle();
  const completion = employerCompanyCompletion(company, documents);
  if (!company) safeError("Create your company profile before submitting for review.");
  if (!completion.infoComplete || !completion.locationComplete || !completion.contactComplete) {
    safeError("Complete company information, location, and contact details before submitting.");
  }
  if (!completion.documentsComplete) safeError("Upload the required trade licence before submitting.");
  // Existing schema uses active company status and pending document status; admin review must approve separately.
  await upsertCompany({ status: "active" });
  redirect(routes.employerDashboard);
}
