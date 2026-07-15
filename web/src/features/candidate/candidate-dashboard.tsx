import { EmptyStateCard } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { StatCard } from "@/components/cards/stat-card";
import { routes } from "@/config/routes";
import { candidateCompletion } from "@/features/candidate/profile-completion";
import type { CandidateMembershipRow, CandidateProfileRow, ProfileRow } from "@/types/domain";

function listSummary(values?: string[] | null) {
  return values && values.length > 0 ? values.slice(0, 3).join(", ") : "Not added yet";
}

function membershipTone(status?: string | null) {
  if (status === "active") return "success" as const;
  if (status === "expired" || status === "cancelled") return "danger" as const;
  return "warning" as const;
}

export function CandidateDashboard({
  profile,
  candidate,
  membership,
}: {
  profile: ProfileRow | null;
  candidate: CandidateProfileRow | null;
  membership: CandidateMembershipRow | null;
}) {
  const completion = candidateCompletion({ profile, candidate });

  return (
    <div className="grid gap-5">
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold text-[#201925]">Membership status</h2>
            <p className="mt-1 text-sm text-[#66616f]">
              Visibility for employers depends on verification, profile readiness, and membership.
            </p>
          </div>
          <StatusBadge tone={membershipTone(membership?.status)}>
            {membership?.status ?? "Inactive"}
          </StatusBadge>
        </div>
        <p className="mt-4 text-sm text-[#3b3340]">
          {membership?.expires_at
            ? `Current plan ${membership.plan_code ?? "membership"} expires on ${new Date(
                membership.expires_at,
              ).toLocaleDateString()}.`
            : "No active membership record was found for this account."}
        </p>
      </section>

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard
          title="Profile completion"
          value={`${completion.percentage}%`}
          note="Complete your headline, location, nationality, and up to three skills."
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

      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <h2 className="text-lg font-semibold text-[#201925]">Selected skills</h2>
        <p className="mt-2 text-sm text-[#66616f]">{listSummary(candidate?.skills)}</p>
      </section>

      <div className="grid gap-4 md:grid-cols-2">
        <EmptyStateCard
          title="Recent matches"
          description="No web match records are shown yet. This foundation will connect to the existing matching tables in a later phase."
        />
        <EmptyStateCard
          title="Employer interest"
          description="Interest requests will appear here after the web workflow is connected to the existing backend."
        />
      </div>

      <EmptyStateCard
        title="Documents"
        description="Document review status is managed by the existing mobile-backed flow. Upload actions are intentionally not duplicated in this web foundation."
        actionHref={routes.candidateDocuments}
        actionLabel="View documents"
      />
    </div>
  );
}
