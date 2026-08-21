import { PageTitle } from "@/components/layout/page-title";
import { StatusBadge } from "@/components/ui/status-badge";
import { MembershipCheckoutButton } from "@/features/candidate/membership/membership-checkout-button";
import { MembershipVisibilityToggle } from "@/features/candidate/membership/membership-visibility-toggle";
import { membershipPresentation } from "@/features/candidate/membership/membership-status";
import { loadCandidateBundle } from "@/features/candidate/server/data";

export default async function CandidateMembershipPage({
  searchParams,
}: {
  searchParams: Promise<{ payment?: string }>;
}) {
  const [{ membership, candidate }, params] = await Promise.all([loadCandidateBundle(), searchParams]);
  const state = membershipPresentation(membership, Boolean(candidate?.is_visible));

  return (
    <div className="grid gap-6">
      <PageTitle title={state.isActive ? "Your KAAM Membership" : "KAAM Lifetime Membership"} description={state.isActive ? "A one-time payment gives you permanent membership." : "Get discovered by employers and receive job opportunities with one lifetime membership."} />
      {params.payment === "cancelled" ? <p className="rounded-lg bg-[#fff4d6] px-4 py-3 text-sm font-semibold text-[#7a5610]">Payment not completed. Your membership was not activated.</p> : null}
      <section className="rounded-2xl border border-[#ded5ed] bg-white p-5 shadow-[0_10px_28px_rgba(22,8,71,.08)] sm:p-7">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-xl font-semibold text-[#201925]">{state.heading}</h2>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-[#66616f]">{state.description}</p>
          </div>
          <StatusBadge tone={state.tone}>{state.badge}</StatusBadge>
        </div>
        {state.isActive ? <>
          <dl className="mt-6 grid gap-4 text-sm sm:grid-cols-3"><div><dt className="text-[#66616f]">Membership</dt><dd className="mt-1 font-semibold text-[#160847]">Lifetime</dd></div><div><dt className="text-[#66616f]">Payment</dt><dd className="mt-1 font-semibold text-[#201925]">AED 50 · Paid</dd></div><div><dt className="text-[#66616f]">Renewal</dt><dd className="mt-1 font-semibold text-[#201925]">Not required</dd></div></dl>
          <section className="mt-7 border-t border-[#eee7f2] pt-6"><h2 className="text-lg font-bold text-[#201925]">Profile Visibility</h2><p className="mt-1 text-sm text-[#66616f]">{state.isVisible ? "Visible to Employers" : "Hidden from Employers"}</p><div className="mt-4"><MembershipVisibilityToggle initialVisible={state.isVisible} /></div>{!state.isVisible ? <p className="mt-3 text-sm text-[#514856]">Turn visibility back on whenever you&apos;re looking for work again.</p> : null}</section>
        </> : <><div className="mt-6 rounded-xl bg-[#f8f5ff] p-4 text-sm text-[#302848]"><p className="font-bold">Lifetime Membership · AED 50</p><p className="mt-1">One-time payment · Lifetime access</p><ul className="mt-3 grid gap-1.5 text-[#514856]"><li>Lifetime KAAM membership</li><li>Appear in employer searches</li><li>Receive job opportunities</li><li>Control your profile visibility anytime</li><li>No renewal or recurring payment</li></ul></div><p className="mt-5 text-sm font-medium text-[#716674]">Your profile remains hidden from employers until membership is activated.</p><div className="mt-6"><MembershipCheckoutButton label={state.action} /></div></>}
      </section>
    </div>
  );
}
