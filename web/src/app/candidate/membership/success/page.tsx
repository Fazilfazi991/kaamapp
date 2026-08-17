import Link from "next/link";
import { PageTitle } from "@/components/layout/page-title";
import { routes } from "@/config/routes";
import { membershipPresentation } from "@/features/candidate/membership/membership-status";
import { loadCandidateBundle } from "@/features/candidate/server/data";

export default async function CandidateMembershipSuccessPage() {
  const { membership } = await loadCandidateBundle();
  const state = membershipPresentation(membership);
  const confirmed = state.isActive;

  return (
    <div className="grid gap-6">
      <PageTitle title={confirmed ? "Payment successful" : "Confirming your payment…"} description={confirmed ? "Your KAAM profile is now visible to Employers for 2 months." : "Stripe is confirming the payment securely. This page never activates membership by itself."} />
      <section className="rounded-lg border border-[#eadde3] bg-white p-6 shadow-sm">
        <p className="text-sm text-[#3b3340]">{confirmed ? state.description : "Refresh this page in a moment. If the status does not update, contact KAAM support with your Checkout confirmation."}</p>
        <Link href={routes.candidateDashboard} className="mt-5 inline-flex rounded-md bg-[#e72f70] px-4 py-2 text-sm font-semibold text-white">Go to Dashboard</Link>
      </section>
    </div>
  );
}
