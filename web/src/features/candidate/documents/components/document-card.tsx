import { ButtonLink } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import { documentStatusLabel, documentTone } from "@/features/candidate/documents/status";
import type { DocumentCardModel } from "@/features/candidate/documents/types";

function formatDate(value: string | null) {
  if (!value) return "Not set";
  return new Date(value).toLocaleDateString();
}

export function DocumentCard({ document }: { document: DocumentCardModel }) {
  const actionHref =
    document.type === "passport"
      ? "/candidate/documents/passport"
      : "/candidate/documents/upload";
  return (
    <article className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-[#201925]">{document.label}</h2>
          <p className="mt-1 text-sm leading-6 text-[#66616f]">{document.description}</p>
        </div>
        <StatusBadge tone={documentTone(document.status)}>
          {documentStatusLabel(document.status)}
        </StatusBadge>
      </div>

      <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-3">
        <div>
          <dt className="font-semibold text-[#3b3340]">Uploaded</dt>
          <dd className="mt-1 text-[#66616f]">{formatDate(document.uploadedAt)}</dd>
        </div>
        <div>
          <dt className="font-semibold text-[#3b3340]">Expiry</dt>
          <dd className="mt-1 text-[#66616f]">{formatDate(document.expiresAt)}</dd>
        </div>
        <div>
          <dt className="font-semibold text-[#3b3340]">Version</dt>
          <dd className="mt-1 text-[#66616f]">{document.version || "None"}</dd>
        </div>
      </dl>

      <div className="mt-5 flex flex-wrap gap-3">
        {document.hasFile ? (
          <>
            <ButtonLink href={`/candidate/documents/${document.type}`} variant="secondary">
              View details
            </ButtonLink>
            <ButtonLink href={actionHref} variant="ghost">
              Replace / resubmit
            </ButtonLink>
          </>
        ) : (
          <ButtonLink href={actionHref}>
            {document.type === "passport" ? "Upload passport" : "Upload support document"}
          </ButtonLink>
        )}
      </div>
    </article>
  );
}
