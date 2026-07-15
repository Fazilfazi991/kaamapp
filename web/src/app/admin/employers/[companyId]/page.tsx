import { notFound } from "next/navigation";
import { Button } from "@/components/ui/button";
import { approveEmployerCompany } from "@/features/admin/server/actions";
import { AdminPageHeader, AdminStatus, DetailSection, Field, SafeLink } from "@/features/admin/components/admin-ui";
import { loadEmployer } from "@/features/admin/server/data";

export default async function AdminEmployerDetailPage({ params }: { params: Promise<{ companyId: string }> }) {
  const { companyId } = await params;
  const company = await loadEmployer(companyId);
  if (!company) notFound();
  return (
    <>
      <AdminPageHeader title={company.company_name} description="Employer company profile, owner account summary, submitted documents, and explicit approval action." />
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
      <DetailSection title="Company approval">
        <p>Approval requires approved trade-license and authorization-letter documents. The action updates existing company status and verification fields only.</p>
        <form action={approveEmployerCompany}>
          <input type="hidden" name="companyId" value={company.id} />
          <Button type="submit">Approve company</Button>
        </form>
      </DetailSection>
    </>
  );
}
