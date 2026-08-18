import { notFound } from "next/navigation";
import { AdminPageHeader, AdminStatus, DetailSection, Field, SafeLink } from "@/features/admin/components/admin-ui";
import { EmployerCompanyVerificationForm } from "@/features/admin/components/employer-review-actions";
import { loadEmployer } from "@/features/admin/server/data";
import {
  documentStatusesByType,
  getEmployerCompanyVerificationState,
  isEmployerCompanyProfileComplete,
} from "@/features/admin/validation/review";

export default async function AdminEmployerDetailPage({ params }: { params: Promise<{ companyId: string }> }) {
  const { companyId } = await params;
  const company = await loadEmployer(companyId);
  if (!company) notFound();
  const profileComplete = isEmployerCompanyProfileComplete(company);
  const verificationState = getEmployerCompanyVerificationState({
    companyStatus: company.status,
    isVerified: company.is_verified,
    profileComplete,
    documentStatuses: documentStatusesByType(company.verification_documents ?? []),
  });
  return (
    <>
      <AdminPageHeader title={company.company_name} description="Employer company profile, owner account summary, and optional business-verification records." />
      <DetailSection title="Company details">
        <div className="grid gap-4 md:grid-cols-3">
          <Field label="Industry" value={company.industry} />
          <Field label="Location" value={[company.office_area, company.city, company.country].filter(Boolean).join(", ")} />
          <Field label="Status" value={<AdminStatus status={company.status} />} />
          <Field label="Verified" value={company.is_verified ? "Yes" : "No"} />
          <Field label="Contact" value={[company.contact_person, company.contact_role].filter(Boolean).join(", ")} />
          <Field label="Owner" value={company.profiles?.email} />
          <Field label="Hiring needs" value={company.hiring_needs?.join(", ")} />
          <Field label="Website" value={company.website} />
          <Field label="Description" value={company.description} />
        </div>
      </DetailSection>
      <DetailSection title="Submitted employer documents">
        {company.verification_documents?.length ? company.verification_documents.map((document) => (
          <p key={document.id}>
            <SafeLink href={`/admin/employer-documents/${document.id}`}>{document.document_type}</SafeLink>{" "}
            <AdminStatus status={document.status} />
          </p>
        )) : <p>No employer documents submitted.</p>}
      </DetailSection>
      <DetailSection title="Optional business verification">
        <p>Employer accounts are already active. A complete company profile may be optionally verified; documents are supporting evidence only.</p>
        <p className="text-sm text-[#66616f]">{verificationState.reason}</p>
        {company.is_verified ? (
          <p><AdminStatus status="approved" /> Business is verified.</p>
        ) : (
          <EmployerCompanyVerificationForm companyId={company.id} canApprove={verificationState.canApprove} />
        )}
      </DetailSection>
    </>
  );
}
