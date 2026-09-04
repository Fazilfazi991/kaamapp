import { PageTitle } from "@/components/layout/page-title";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default async function CandidateJobsPage({ searchParams }: { searchParams: Promise<{ requirement?: string }> }) {
  const requirement = (await searchParams).requirement;
  const cameFromDemoRequirement = requirement?.startsWith("demo-") ?? false;

  return (
    <div className="grid gap-6">
      <PageTitle title="Jobs" description="Matched and recommended jobs will appear here after the query contract is finalized." />
      {cameFromDemoRequirement ? <p className="rounded-xl bg-[#f7f4ff] px-4 py-3 text-sm leading-6 text-[#3f3262]">You registered after viewing this job requirement. Complete your profile to get matched with similar opportunities.</p> : null}
      <EmptyStateCard title="No jobs loaded" description="This screen is a structured placeholder and does not fabricate production job records." />
    </div>
  );
}
