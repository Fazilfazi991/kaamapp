import { notFound } from "next/navigation";
import { PageTitle } from "@/components/layout/page-title";
import { SecureDocumentViewer } from "@/components/documents/secure-document-viewer";
import { ButtonLink } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import { documentStatusLabel, documentTone, normalizeStatus } from "@/features/candidate/documents/status";
import { loadCandidateDocumentDetails } from "@/features/candidate/documents/server/data";
import type { CandidateDocumentType } from "@/features/candidate/documents/types";

function formatDate(value: string | null | undefined) {
  if (!value) return "Not set";
  return new Date(value).toLocaleDateString();
}

function safeDocumentType(value: string): CandidateDocumentType | null {
  return value === "passport" || value === "visa" ? value : null;
}

export default async function CandidateDocumentDetailsPage({
  params,
}: {
  params: Promise<{ documentId: string }>;
}) {
  const { documentId } = await params;
  const type = safeDocumentType(documentId);
  if (!type) notFound();
  const { row, versions, hasFile, previewKind } = await loadCandidateDocumentDetails(type);
  const isPassport = type === "passport";
  const status = normalizeStatus(isPassport ? row?.passport_status : row?.visa_status);

  return (
    <div className="grid gap-6">
      <PageTitle
        title={isPassport ? "Passport details" : "Visa details"}
        description="Private document previews are loaded through an authenticated KAAM route."
      />

      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold text-[#201925]">
              {isPassport ? "Passport" : "Visa / Emirates ID support"}
            </h2>
            <p className="mt-1 text-sm text-[#66616f]">
              {hasFile ? "Document uploaded securely." : "No document file is uploaded yet."}
            </p>
          </div>
          <StatusBadge tone={documentTone(status)}>{documentStatusLabel(status)}</StatusBadge>
        </div>

        {hasFile ? (
          <div className="mt-5">
            <SecureDocumentViewer
              documentKey={type}
              kind={previewKind}
              previewUrl={`/candidate/documents/preview/${type}`}
              title={`${type} document preview`}
            />
          </div>
        ) : null}

        <dl className="mt-5 grid gap-4 text-sm md:grid-cols-2">
          {(isPassport
            ? [
                ["Full name", row?.full_name],
                ["Passport number", row?.passport_number],
                ["Nationality", row?.nationality],
                ["Date of birth", row?.dob],
                ["Gender", row?.gender],
                ["Issue date", row?.passport_issue_date],
                ["Expiry date", row?.passport_expiry_date],
                ["Place of birth", row?.place_of_birth],
                ["Country of issue", row?.country_of_issue],
              ]
            : [
                ["Visa number", row?.visa_number],
                ["Visa type", row?.visa_type],
                ["Occupation", row?.occupation],
                ["Sponsor", row?.sponsor],
                ["UID number", row?.uid_number],
                ["Emirates ID", row?.emirates_id],
                ["Issue date", row?.visa_issue_date],
                ["Expiry date", row?.visa_expiry_date],
              ]
          ).map(([label, value]) => (
            <div key={label}>
              <dt className="font-semibold text-[#3b3340]">{label}</dt>
              <dd className="mt-1 text-[#66616f]">{String(value || "Not set")}</dd>
            </div>
          ))}
        </dl>

        <div className="mt-5 flex flex-wrap gap-3">
          <ButtonLink href={isPassport ? "/candidate/documents/passport" : "/candidate/documents/upload"}>
            Replace / resubmit
          </ButtonLink>
          {isPassport ? (
            <ButtonLink href="/candidate/documents/passport/review" variant="secondary">
              Review fields
            </ButtonLink>
          ) : null}
        </div>
      </section>

      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <h2 className="text-lg font-semibold text-[#201925]">Version history</h2>
        <div className="mt-4 grid gap-3">
          {versions.length ? (
            versions.map((version) => (
              <div
                key={version.id}
                className="flex flex-wrap items-center justify-between gap-3 rounded-lg bg-[#f7f2f5] p-4 text-sm"
              >
                <span className="font-semibold text-[#3b3340]">Version {version.version_number}</span>
                <span className="text-[#66616f]">{formatDate(version.created_at)}</span>
                <StatusBadge tone={documentTone(normalizeStatus(version.status))}>
                  {version.is_active ? "Active" : "Archived"}
                </StatusBadge>
              </div>
            ))
          ) : (
            <p className="text-sm text-[#66616f]">No version history yet.</p>
          )}
        </div>
      </section>
    </div>
  );
}
