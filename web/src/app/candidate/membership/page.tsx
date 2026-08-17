import { PageTitle } from "@/components/layout/page-title";
import { StatusBadge } from "@/components/ui/status-badge";
import { MembershipCheckoutButton } from "@/features/candidate/membership/membership-checkout-button";
import { membershipPresentation } from "@/features/candidate/membership/membership-status";
import { loadCandidateBundle } from "@/features/candidate/server/data";

export default async function CandidateMembershipPage({
  searchParams,
}: {
  searchParams: Promise<{ payment?: string }>;
}) {
  const [{ membership }, params] = await Promise.all([loadCandidateBundle(), searchParams]);
  const state = membershipPresentation(membership);

  return (
    <div className="grid gap-6">
      <PageTitle title="KAAM Membership" description="Profile visibility to Employers requires an active membership." />
      {params.payment === "cancelled" ? <p className="rounded-lg bg-[#fff4d6] px-4 py-3 text-sm font-semibold text-[#7a5610]">Payment not completed. Your membership was not activated.</p> : null}
      <section className="rounded-lg border border-[#eadde3] bg-white p-6 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-xl font-semibold text-[#201925]">{state.heading}</h2>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-[#66616f]">{state.description}</p>
          </div>
          <StatusBadge tone={state.tone}>{state.badge}</StatusBadge>
        </div>
        <dl className="mt-5 grid gap-3 text-sm sm:grid-cols-2">
          <div><dt className="text-[#66616f]">Price</dt><dd className="font-semibold text-[#201925]">AED 50.00</dd></div>
          <div><dt className="text-[#66616f]">Validity</dt><dd className="font-semibold text-[#201925]">2 calendar months</dd></div>
          <div><dt className="text-[#66616f]">Visibility</dt><dd className="font-semibold text-[#201925]">{state.isActive ? "Visible to Employers" : "Hidden from Employer Search"}</dd></div>
          <div><dt className="text-[#66616f]">Renewal</dt><dd className="font-semibold text-[#201925]">One-time payment. No automatic renewal.</dd></div>
        </dl>
        <div className="mt-6"><MembershipCheckoutButton label={state.action} /></div>
      </section>
    </div>
  );
}
