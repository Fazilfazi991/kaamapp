import type { EmployerCompany, VerificationDocumentRow } from "@/features/employer/types";

export const employerRequiredDocumentTypes = ["trade-license"] as const;

export function employerCompanyCompletion(company: EmployerCompany | null, documents: VerificationDocumentRow[] = []) {
  const infoComplete = Boolean(
    company?.company_name?.trim() &&
      company?.industry?.trim() &&
      company?.company_size?.trim() &&
      company?.trade_license_number?.trim(),
  );
  const locationComplete = Boolean(company?.country?.trim() && company?.city?.trim());
  const contactComplete = Boolean(company?.contact_person?.trim() && company?.contact_role?.trim());
  const activeDocTypes = new Set(
    documents
      .filter((document) => document.status !== "rejected")
      .map((document) => document.document_type),
  );
  const documentsComplete = employerRequiredDocumentTypes.every((type) => activeDocTypes.has(type));
  const completed = [infoComplete, locationComplete, contactComplete, documentsComplete].filter(Boolean).length;
  return {
    infoComplete,
    locationComplete,
    contactComplete,
    logoComplete: Boolean(company?.logo_url?.trim()),
    documentsComplete,
    reviewStatus: company?.is_verified ? "approved" : documentsComplete ? "pending_review" : "draft",
    approvalStatus: company?.status ?? "draft",
    percentage: Math.round((completed / 4) * 100),
    isComplete: infoComplete && locationComplete && contactComplete && documentsComplete,
  };
}

export function nextEmployerOnboardingPath(company: EmployerCompany | null, documents: VerificationDocumentRow[] = []) {
  const completion = employerCompanyCompletion(company, documents);
  if (!company || !completion.infoComplete) return "/employer/onboarding/company";
  if (!completion.locationComplete) return "/employer/onboarding/location";
  if (!completion.contactComplete) return "/employer/onboarding/contact";
  if (!completion.documentsComplete) return "/employer/onboarding/documents";
  return "/employer/onboarding/review";
}
