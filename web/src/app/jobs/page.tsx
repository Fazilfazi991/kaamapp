import type { Metadata } from "next";

import { Footer } from "@/components/layout/footer";
import { Header } from "@/components/layout/header";
import { HotJobsSection } from "@/components/marketing/hot-jobs-section";
import { PageHero } from "@/components/marketing/page-hero";
import { loadPublicHiringRequirements } from "@/features/public-jobs/data";

export const metadata: Metadata = {
  title: "Jobs hiring now",
  description: "Explore active job requirements from employers on KAAM.",
};

export default async function PublicJobsPage() {
  const jobs = await loadPublicHiringRequirements(15);
  return (
    <>
      <Header />
      <main>
        <PageHero eyebrow="Current opportunities" title="Jobs hiring now.">Explore active, published requirements and register your KAAM Candidate profile to continue.</PageHero>
        {jobs.length ? <div className="px-4 pb-12 sm:px-6 lg:px-8"><HotJobsSection jobs={jobs} compact /></div> : <section className="mx-auto max-w-3xl px-4 py-16 text-center sm:px-6"><h2 className="text-2xl font-bold text-[#160847]">New job requirements are coming soon.</h2><p className="mt-3 text-[#675d79]">Please check back for newly published opportunities.</p></section>}
      </main>
      <Footer />
    </>
  );
}
