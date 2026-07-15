import { notFound } from "next/navigation";
import { PageTitle } from "@/components/layout/page-title";
import { EmployerCandidateCard } from "@/features/employer/components/candidate-card";
import { loadEmployerCandidate } from "@/features/employer/server/data";

export default async function EmployerCandidateDetailsPage({
  params,
}: {
  params: Promise<{ candidateId: string }>;
}) {
  const { candidateId } = await params;
  const candidate = await loadEmployerCandidate(candidateId);
  if (!candidate) notFound();

  return (
    <div className="grid gap-6">
      <PageTitle
        title="Candidate profile"
        description="Employer-visible profile only. Private contact, date of birth, documents, and OCR fields are hidden."
      />
      <EmployerCandidateCard candidate={candidate} />
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <h2 className="text-lg font-semibold text-[#201925]">Profile summary</h2>
        <dl className="mt-4 grid gap-4 text-sm md:grid-cols-2">
          <div>
            <dt className="font-semibold text-[#3b3340]">Preferred location</dt>
            <dd className="mt-1 text-[#66616f]">{candidate.preferredLocation}</dd>
          </div>
          <div>
            <dt className="font-semibold text-[#3b3340]">Languages</dt>
            <dd className="mt-1 text-[#66616f]">{candidate.languages.join(", ") || "Not shared"}</dd>
          </div>
          <div>
            <dt className="font-semibold text-[#3b3340]">Verification</dt>
            <dd className="mt-1 text-[#66616f]">
              {candidate.isVerified ? "Identity verified" : "Identity verification pending"}
            </dd>
          </div>
          <div>
            <dt className="font-semibold text-[#3b3340]">Contact</dt>
            <dd className="mt-1 text-[#66616f]">
              Contact details become available only after the existing match and candidate reveal rules allow access.
            </dd>
          </div>
        </dl>
      </section>
    </div>
  );
}
