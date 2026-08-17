import { EmptyStateCard } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { StatCard } from "@/components/cards/stat-card";
import { routes } from "@/config/routes";
import { MembershipCheckoutButton } from "@/features/candidate/membership/membership-checkout-button";
import { membershipPresentation } from "@/features/candidate/membership/membership-status";
import { candidateCompletion } from "@/features/candidate/profile-completion";
import type { CandidateMembershipRow, CandidateProfileRow, ProfileRow } from "@/types/domain";

function listSummary(values?: string[] | null) {
  return values && values.length > 0 ? values.slice(0, 3).join(", ") : "Not added yet";
}

export function CandidateDashboard({
  profile,
  candidate,
  membership,
  hasPassport,
  counts,
}: {
  profile: ProfileRow | null;
  candidate: CandidateProfileRow | null;
  membership: CandidateMembershipRow | null;
  hasPassport: boolean;
  counts?: {
    pendingInterests: number;
    acceptedInterests: number;
    matches: number;
    unreadMessages: number;
  };
}) {
  const completion = candidateCompletion({ profile, candidate, hasPassport });
  const membershipState = membershipPresentation(membership);

  return (
    <div className="grid gap-5">
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold text-[#201925]">{membershipState.heading}</h2>
            <p className="mt-1 text-sm text-[#66616f]">
              AED 50 for 2 calendar months. One-time payment. No automatic renewal.
            </p>
          </div>
          <StatusBadge tone={membershipState.tone}>
            {membershipState.badge}
          </StatusBadge>
        </div>
        <p className="mt-4 text-sm text-[#3b3340]">{membershipState.description}</p>
        <p className={`mt-2 text-sm font-semibold ${membershipState.isActive ? "text-[#176b3b]" : "text-[#a12a4d]"}`}>
          {membershipState.isActive ? "Visible to Employers" : "Hidden from Employer Search"}
        </p>
        <div className="mt-4"><MembershipCheckoutButton label={membershipState.action} /></div>
      </section>

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard
          title="Profile completion"
          value={`${completion.percentage}%`}
          note="Complete your details, skills, work preferences and required identity document."
          tone={completion.isComplete ? "success" : "warning"}
        />
        <StatCard
          title="Verification"
          value={candidate?.is_verified ? "Verified" : "Pending"}
          note="Document review status comes from the existing candidate profile."
          tone={candidate?.is_verified ? "success" : "warning"}
        />
        <StatCard
          title="Availability"
          value={candidate?.availability ?? "Unset"}
          note="Keep this current so employers can understand when you can join."
        />
      </div>

      <div className="grid gap-4 md:grid-cols-4">
        <StatCard
          title="Pending interests"
          value={String(counts?.pendingInterests ?? 0)}
          note="Employer requests waiting for your response."
          tone={(counts?.pendingInterests ?? 0) > 0 ? "warning" : "neutral"}
        />
        <StatCard
          title="Accepted interests"
          value={String(counts?.acceptedInterests ?? 0)}
          note="Accepted requests remain visible in your interest history."
          tone={(counts?.acceptedInterests ?? 0) > 0 ? "success" : "neutral"}
        />
        <StatCard
          title="Matches"
          value={String(counts?.matches ?? 0)}
          note="Matches are created after you accept an interest."
          tone={(counts?.matches ?? 0) > 0 ? "success" : "neutral"}
        />
        <StatCard
          title="Unread messages"
          value={String(counts?.unreadMessages ?? 0)}
          note="Unread matched-chat messages."
          tone={(counts?.unreadMessages ?? 0) > 0 ? "warning" : "neutral"}
        />
      </div>

      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <h2 className="text-lg font-semibold text-[#201925]">Selected skills</h2>
        <p className="mt-2 text-sm text-[#66616f]">{listSummary(candidate?.skills)}</p>
      </section>

      {!completion.isComplete ? <section className="rounded-lg border border-[#eadde3] bg-[#fffafc] p-5"><h2 className="text-lg font-semibold text-[#201925]">Still required</h2><div className="mt-3 flex flex-wrap gap-2">{completion.missingSections.map((section) => <a key={section.id} href={section.href} className="focus-ring rounded-lg border border-[#e53670] bg-white px-3 py-2 text-sm font-semibold text-[#bc1f55]">Complete {section.label}</a>)}</div></section> : null}

      <div className="grid gap-4 md:grid-cols-2">
        <EmptyStateCard
          title="Employer interests"
          description="Review incoming employer interest requests and accept or reject pending requests."
          actionHref={routes.candidateInterests}
          actionLabel="View interests"
        />
        <EmptyStateCard
          title="Messages"
          description="Open conversations for accepted matches when the backend chat rule allows messaging."
          actionHref={routes.candidateMessages}
          actionLabel="Open messages"
        />
      </div>

      <EmptyStateCard
        title="Documents"
        description="Upload passport and supporting documents securely, review OCR fields, and track pending verification."
        actionHref={routes.candidateDocuments}
        actionLabel="View documents"
      />
    </div>
  );
}
