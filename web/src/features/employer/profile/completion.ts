import type { EmployerCompany, VerificationDocumentRow } from "@/features/employer/types";
import { validateEmployerLocation } from "./validation";

// Employer verification evidence is optional and admin-managed. Historical
// verification documents remain supported, but are not onboarding prerequisites.
export const employerRequiredDocumentTypes = [] as const;

export function employerCompanyCompletion(company: EmployerCompany | null, documents: VerificationDocumentRow[] = []) {
  void documents; // Kept for callers that load historical document bundles.
  const infoComplete = Boolean(
      company?.company_name?.trim() &&
      company?.industry?.trim() &&
      company?.company_size?.trim(),
  );
  const locationComplete = company
    ? validateEmployerLocation(company.country ?? "", company.city ?? "", company.office_area ?? "").ok
    : false;
  const contactComplete = Boolean(company?.contact_person?.trim() && company?.contact_role?.trim());
  const documentsComplete = true;
  const completed = [infoComplete, locationComplete, contactComplete].filter(Boolean).length;
  return {
    infoComplete,
    locationComplete,
    contactComplete,
    logoComplete: Boolean(company?.logo_url?.trim()),
    documentsComplete,
    reviewStatus: company?.is_verified ? "approved" : "not_verified",
    approvalStatus: company?.status ?? "draft",
    percentage: Math.round((completed / 3) * 100),
    isComplete: infoComplete && locationComplete && contactComplete,
  };
}

export function nextEmployerOnboardingPath(company: EmployerCompany | null, documents: VerificationDocumentRow[] = []) {
  const completion = employerCompanyCompletion(company, documents);
  if (!company || !completion.infoComplete) return "/employer/onboarding/company";
  if (!completion.locationComplete) return "/employer/onboarding/location";
  if (!completion.contactComplete) return "/employer/onboarding/contact";
  return "/employer/dashboard";
}
