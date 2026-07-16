import { Button, ButtonLink } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import { acceptInterest, rejectInterest } from "@/features/candidate/interests/server/actions";
import { canRespondToInterest, extractInterestLine, interestStatusLabel, interestTone } from "@/features/candidate/interests/utils";
import type { CandidateInterestRow } from "@/features/candidate/interests/types";

export function CandidateInterestCard({ interest, detailed = false }: { interest: CandidateInterestRow; detailed?: boolean }) {
  const company = interest.employer_companies;
  const role = extractInterestLine(interest.message, "Role") || "Role shared in message";
  const salary = extractInterestLine(interest.message, "Salary") || "Salary not shared";
  return (
    <article className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-[#201925]">{company?.company_name ?? "Employer"}</h2>
          <p className="mt-1 text-sm text-[#66616f]">
            {[company?.industry, company?.city, company?.country].filter(Boolean).join(" - ") || "Company details"}
          </p>
        </div>
        <StatusBadge tone={interestTone(interest.status)}>{interestStatusLabel(interest.status)}</StatusBadge>
      </div>
      <dl className="mt-4 grid gap-3 text-sm md:grid-cols-3">
        <div>
          <dt className="font-semibold text-[#3b3340]">Role</dt>
          <dd className="mt-1 text-[#66616f]">{role}</dd>
        </div>
        <div>
          <dt className="font-semibold text-[#3b3340]">Salary</dt>
          <dd className="mt-1 text-[#66616f]">{salary}</dd>
        </div>
        <div>
          <dt className="font-semibold text-[#3b3340]">Sent</dt>
          <dd className="mt-1 text-[#66616f]">{new Date(interest.created_at).toLocaleDateString()}</dd>
        </div>
      </dl>
      {detailed ? (
        <div className="mt-4 rounded-lg bg-[#f7f2f5] p-4 text-sm leading-6 text-[#3b3340] whitespace-pre-wrap">
          {interest.message || "No message was included."}
        </div>
      ) : null}
      <p className="mt-4 text-sm leading-6 text-[#66616f]">
        Accepting this interest creates a match through the existing database trigger. Contact sharing and messaging still follow your membership and privacy rules.
      </p>
      <div className="mt-5 flex flex-wrap gap-3">
        {!detailed ? (
          <ButtonLink href={`/candidate/interests/${interest.id}`} variant="secondary">
            View details
          </ButtonLink>
        ) : null}
        {canRespondToInterest(interest.status) ? (
          <>
            <form action={acceptInterest}>
              <input type="hidden" name="interestId" value={interest.id} />
              <Button type="submit">Accept</Button>
            </form>
            <form action={rejectInterest}>
              <input type="hidden" name="interestId" value={interest.id} />
              <Button type="submit" variant="ghost">Reject</Button>
            </form>
          </>
        ) : null}
      </div>
    </article>
  );
}
