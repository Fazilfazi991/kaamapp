import { PageTitle } from "@/components/layout/page-title";
import { PassportReviewForm } from "@/features/candidate/documents/components/passport-review-form";
import { loadCandidateDocuments } from "@/features/candidate/documents/server/data";

export default async function CandidatePassportReviewPage({
  searchParams,
}: {
  searchParams: Promise<{ ocr?: string }>;
}) {
  const [{ row }, params] = await Promise.all([loadCandidateDocuments(), searchParams]);

  return (
    <div className="grid gap-6">
      <PageTitle
        title="Passport review"
        description="Confirm the extracted fields before submitting the document for review."
      />
      <PassportReviewForm row={row} ocr={params.ocr} />
    </div>
  );
}
