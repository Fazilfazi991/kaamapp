import { notFound } from "next/navigation";
import { PageTitle } from "@/components/layout/page-title";
import { ButtonLink } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import { documentLabel } from "@/features/employer/documents/components";
import { getOwnedVerificationDocument } from "@/features/employer/server/profile-data";

export default async function EmployerDocumentDetailsPage({ params }: { params: Promise<{ documentId: string }> }) {
  const { documentId } = await params;
  const document = await getOwnedVerificationDocument(documentId);
  if (!document) notFound();
  return (
    <div className="grid gap-6">
      <PageTitle title={documentLabel(document.document_type)} description="Private document preview is proxied through an authenticated route." />
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <StatusBadge tone={document.status === "approved" ? "success" : "warning"}>{document.status}</StatusBadge>
        <p className="mt-4 text-sm text-[#66616f]">Uploaded {new Date(document.created_at).toLocaleDateString()}</p>
        <iframe title="Secure document preview" src={`/employer/documents/preview/${document.id}`} className="mt-5 h-[420px] w-full rounded-lg border border-[#eadde3]" />
        <div className="mt-5"><ButtonLink href="/employer/documents/upload">Replace / resubmit</ButtonLink></div>
      </section>
    </div>
  );
}
