import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { ButtonLink } from "@/components/ui/button";
import { DocumentCard } from "@/features/candidate/documents/components/document-card";
import { loadCandidateDocuments } from "@/features/candidate/documents/server/data";

export default async function CandidateDocumentsPage() {
  const { cards, loadError } = await loadCandidateDocuments();

  return (
    <div className="grid gap-6">
      <PageTitle
        title="Documents"
        description="Upload identity and supporting documents securely for KAAM review."
      />

      {loadError ? (
        <EmptyStateCard
          title="Document status unavailable"
          description="We could not load the latest document status. You can still try again after checking your connection."
        />
      ) : null}

      <div className="grid gap-4">
        {cards.map((document) => (
          <DocumentCard key={document.type} document={document} />
        ))}
      </div>

      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <h2 className="text-lg font-semibold text-[#201925]">Need to upload another document?</h2>
        <p className="mt-2 text-sm leading-6 text-[#66616f]">
          Use the upload screen for supported identity and visa files. Each new upload creates a new pending version.
        </p>
        <div className="mt-4">
          <ButtonLink href="/candidate/documents/upload" variant="secondary">
            Open upload options
          </ButtonLink>
        </div>
      </section>
    </div>
  );
}
