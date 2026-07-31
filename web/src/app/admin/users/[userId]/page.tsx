import { notFound } from "next/navigation";
import { Button } from "@/components/ui/button";
import { blockUser, unblockUser } from "@/features/admin/server/actions";
import { AdminPageHeader, AdminStatus, DetailSection, Field, SafeLink } from "@/features/admin/components/admin-ui";
import { loadUser } from "@/features/admin/server/data";

type RelatedCompany = {
  id: string;
  company_name: string;
};

export default async function AdminUserDetailPage({ params }: { params: Promise<{ userId: string }> }) {
  const { userId } = await params;
  const { profile, candidate, companies } = await loadUser(userId);
  if (!profile) notFound();
  return (
    <>
      <AdminPageHeader title={profile.full_name ?? profile.email ?? "User"} description="Safe account summary, related candidate/employer records, and supported account actions." />
      <DetailSection title="Account">
        <div className="grid gap-4 md:grid-cols-3">
          <Field label="Email" value={profile.email} />
          <Field label="Role" value={profile.role} />
          <Field label="Status" value={<AdminStatus status={profile.status} />} />
          <Field label="Registered" value={profile.created_at?.slice(0, 10)} />
          <Field label="Updated" value={profile.updated_at?.slice(0, 10)} />
        </div>
      </DetailSection>
      <DetailSection title="Related records">
        {candidate ? <p>Candidate profile: <SafeLink href={`/admin/candidates/${candidate.id}`}>{candidate.headline ?? candidate.id}</SafeLink></p> : <p>No candidate profile.</p>}
        {companies.length ? (companies as RelatedCompany[]).map((company) => (
          <p key={company.id}>Employer company: <SafeLink href={`/admin/employers/${company.id}`}>{company.company_name}</SafeLink></p>
        )) : <p>No employer company.</p>}
      </DetailSection>
      <DetailSection title="Account actions">
        <form action={profile.status === "blocked" ? unblockUser : blockUser}>
          <input type="hidden" name="userId" value={profile.id} />
          <Button type="submit" variant="secondary">{profile.status === "blocked" ? "Unblock account" : "Block account"}</Button>
        </form>
      </DetailSection>
    </>
  );
}
