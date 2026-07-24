import { ButtonLink } from "@/components/ui/button";
import { CandidateAvatar } from "@/components/ui/candidate-avatar";
import { StatusBadge } from "@/components/ui/status-badge";
import { routes } from "@/config/routes";
import { candidateCompletion } from "@/features/candidate/profile-completion";
import type { CandidateMembershipRow, CandidateProfileRow, ProfileRow } from "@/types/domain";

function value(text?: string | number | null) {
  return text === null || text === undefined || text === "" ? "Not added" : String(text);
}

function list(values?: string[] | null) {
  return values?.length ? values.join(", ") : "Not added";
}

export async function ProfileSummary({
  profile,
  candidate,
  membership,
}: {
  profile: ProfileRow | null;
  candidate: CandidateProfileRow | null;
  membership?: CandidateMembershipRow | null;
}) {
  const completion = candidateCompletion({ profile, candidate });
  return (
    <div className="grid gap-5">
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="flex items-center gap-4">
            <CandidateAvatar path={candidate?.profile_photo_url} name={profile?.full_name} size={80} />
            <div>
              <h1 className="text-2xl font-bold text-[#201925]">
                {value(profile?.full_name)}
              </h1>
              <p className="mt-1 text-sm text-[#66616f]">{value(candidate?.headline)}</p>
            </div>
          </div>
          <ButtonLink href={routes.candidateProfileEdit}>Edit Profile</ButtonLink>
        </div>
        <div className="mt-4 flex flex-wrap gap-2">
          <StatusBadge tone={completion.isComplete ? "success" : "warning"}>
            {completion.percentage}% complete
          </StatusBadge>
          <StatusBadge tone={candidate?.is_verified ? "success" : "warning"}>
            {candidate?.is_verified ? "Verified" : "Verification pending"}
          </StatusBadge>
          <StatusBadge tone={membership?.status === "active" ? "success" : "neutral"}>
            Membership {membership?.status ?? "inactive"}
          </StatusBadge>
        </div>
      </section>
      <Section title="Personal details" rows={[
        ["Phone", value(profile?.phone)],
        ["Nationality", value(candidate?.nationality)],
        ["About", value(candidate?.bio)],
      ]} />
      <Section title="Skills" rows={[
        ["Categories", list(candidate?.job_categories)],
        ["Selected skills", list(candidate?.skills)],
      ]} />
      <Section title="Location" rows={[
        ["Current residence", `${value(candidate?.current_country)} · ${value(candidate?.current_city)}`],
        ["Preferred work location", `${value(candidate?.preferred_country)} · ${value(candidate?.preferred_city)}`],
      ]} />
      <Section title="Experience and privacy" rows={[
        ["Availability", value(candidate?.availability)],
        ["Experience", candidate?.experience_years == null ? "Not added" : `${candidate.experience_years} years`],
        ["Expected salary", candidate?.expected_salary_min || candidate?.expected_salary_max ? `${value(candidate?.expected_salary_min)}-${value(candidate?.expected_salary_max)} ${candidate?.currency ?? "AED"}` : "Not added"],
        ["Languages", list(candidate?.languages)],
        ["Phone privacy", candidate?.hide_phone_before_match === false ? "Visible after match rules allow" : "Hidden before match"],
      ]} />
    </div>
  );
}

function Section({ title, rows }: { title: string; rows: Array<[string, string]> }) {
  return (
    <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <h2 className="text-lg font-semibold text-[#201925]">{title}</h2>
      <dl className="mt-4 grid gap-3 sm:grid-cols-2">
        {rows.map(([label, text]) => (
          <div key={label}>
            <dt className="text-xs font-semibold uppercase tracking-[0.12em] text-[#8a7c88]">
              {label}
            </dt>
            <dd className="mt-1 text-sm text-[#342b38]">{text}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
