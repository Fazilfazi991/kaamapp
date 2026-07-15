import { ButtonLink } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import { normalizePhoneForWhatsApp } from "@/features/employer/utils";
import type { MatchContactRow } from "@/features/employer/types";

export function MatchCard({ match }: { match: MatchContactRow }) {
  const canContact = match.contact_revealed === true;
  const whatsapp = match.phone ? normalizePhoneForWhatsApp(match.phone) : "";
  return (
    <article className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-[#201925]">{match.display_name ?? "Matched candidate"}</h2>
          <p className="mt-1 text-sm text-[#66616f]">{match.role ?? "Candidate"} · {match.location ?? "Location not set"}</p>
        </div>
        <StatusBadge tone={match.chat_enabled ? "success" : "warning"}>
          {match.chat_enabled ? "Chat available" : "Contact locked"}
        </StatusBadge>
      </div>
      <p className="mt-4 text-sm leading-6 text-[#66616f]">
        {canContact
          ? "The candidate has revealed contact details for this match."
          : "Contact details become available after the candidate unlocks contact sharing for this match."}
      </p>
      {canContact ? (
        <div className="mt-4 grid gap-2 text-sm text-[#3b3340]">
          {match.phone ? <a className="font-semibold text-[#bc1f55]" href={`tel:${match.phone}`}>Call candidate</a> : <span>Phone not shared</span>}
          {whatsapp ? <a className="font-semibold text-[#bc1f55]" href={`https://wa.me/${whatsapp}`}>Open WhatsApp</a> : null}
          {match.email ? <a className="font-semibold text-[#bc1f55]" href={`mailto:${match.email}`}>Email candidate</a> : <span>Email not shared</span>}
        </div>
      ) : null}
      <div className="mt-5 flex flex-wrap gap-3">
        <ButtonLink href={`/employer/candidates/${match.candidate_id}`} variant="secondary">
          View profile
        </ButtonLink>
        {match.chat_enabled ? (
          <ButtonLink href="/employer/messages">Open chat</ButtonLink>
        ) : null}
      </div>
    </article>
  );
}
