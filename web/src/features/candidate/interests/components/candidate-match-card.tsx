import { Button, ButtonLink } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import { revealContactForMatch } from "@/features/candidate/interests/server/actions";
import type { CandidateMatchRow } from "@/features/candidate/interests/types";

export function CandidateMatchCard({ match }: { match: CandidateMatchRow }) {
  return (
    <article className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-[#201925]">{match.company_name ?? "Matched employer"}</h2>
          <p className="mt-1 text-sm text-[#66616f]">
            {[match.role, match.location].filter(Boolean).join(" - ") || "Matched company"}
          </p>
        </div>
        <StatusBadge tone={match.chat_enabled ? "success" : "warning"}>
          {match.chat_enabled ? "Messaging available" : "Membership required"}
        </StatusBadge>
      </div>
      <p className="mt-4 text-sm leading-6 text-[#66616f]">
        {match.contact_revealed
          ? "Contact details have been revealed to this employer."
          : match.can_reveal_contact
            ? "You can reveal contact details for this match when you are ready."
            : "Contact details remain hidden until the backend contact rules allow reveal."}
      </p>
      <div className="mt-5 flex flex-wrap gap-3">
        {match.chat_enabled ? (
          <ButtonLink href={`/candidate/messages/${match.match_id}`}>Open chat</ButtonLink>
        ) : null}
        {match.can_reveal_contact ? (
          <form action={revealContactForMatch}>
            <input type="hidden" name="matchId" value={match.match_id} />
            <Button type="submit" variant="secondary">Reveal contact</Button>
          </form>
        ) : null}
      </div>
    </article>
  );
}
