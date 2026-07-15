import { PageTitle } from "@/components/layout/page-title";
import { ButtonLink } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import { EmployerDocumentCards } from "@/features/employer/documents/components";
import { employerCompanyCompletion } from "@/features/employer/profile/completion";
import { loadEmployerCompanyBundle } from "@/features/employer/server/profile-data";

export default async function EmployerProfilePage() {
  const { company, documents } = await loadEmployerCompanyBundle();
  const completion = employerCompanyCompletion(company, documents);
  return (
    <div className="grid gap-6">
      <PageTitle title="Company Profile" description="Private company profile summary for the authenticated employer owner." />
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold text-[#201925]">{company?.company_name ?? "Company profile not created"}</h2>
            <p className="mt-1 text-sm text-[#66616f]">{[company?.industry, company?.city, company?.country].filter(Boolean).join(" - ") || "Complete onboarding to enable employer workflows."}</p>
          </div>
          <StatusBadge tone={company?.is_verified ? "success" : "warning"}>{company?.is_verified ? "Verified" : "Review pending"}</StatusBadge>
        </div>
        <dl className="mt-5 grid gap-4 text-sm md:grid-cols-2">
          <div><dt className="font-semibold text-[#3b3340]">Trade licence</dt><dd className="mt-1 text-[#66616f]">{company?.trade_license_number ? "Saved" : "Missing"}</dd></div>
          <div><dt className="font-semibold text-[#3b3340]">Company size</dt><dd className="mt-1 text-[#66616f]">{company?.company_size ?? "Not set"}</dd></div>
          <div><dt className="font-semibold text-[#3b3340]">Contact person</dt><dd className="mt-1 text-[#66616f]">{company?.contact_person ?? "Not set"}</dd></div>
          <div><dt className="font-semibold text-[#3b3340]">Completion</dt><dd className="mt-1 text-[#66616f]">{completion.percentage}%</dd></div>
        </dl>
        <div className="mt-5 flex flex-wrap gap-3">
          <ButtonLink href="/employer/profile/edit">Edit Company Profile</ButtonLink>
          <ButtonLink href="/employer/documents" variant="secondary">Manage Documents</ButtonLink>
          <ButtonLink href="/employer/dashboard" variant="ghost">Return to Dashboard</ButtonLink>
        </div>
      </section>
      <EmployerDocumentCards documents={documents} />
    </div>
  );
}
