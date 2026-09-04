import Link from "next/link";

import { HotJobsCarousel } from "@/components/marketing/hot-jobs-carousel";
import { routes } from "@/config/routes";
import type { PublicHiringRequirement } from "@/features/public-jobs/types";

export function HotJobsSection({ jobs, compact = false }: { jobs: PublicHiringRequirement[]; compact?: boolean }) {
  if (!jobs.length) return null;

  return (
    <section className={compact ? "bg-white px-0 py-4" : "overflow-hidden bg-white px-0 py-10 sm:px-6 sm:py-14 lg:px-8 lg:py-16"} aria-labelledby="hot-jobs-heading">
      <div className={`mx-auto max-w-[1440px] overflow-hidden bg-[radial-gradient(circle_at_10%_20%,rgba(245,107,161,.06),transparent_32%),linear-gradient(135deg,#faf8ff_0%,#f4f1ff_100%)] ${compact ? "rounded-2xl py-8" : "py-9 sm:rounded-[28px] sm:px-8 sm:py-11 lg:px-10"}`}>
        <div className="grid min-w-0 gap-8 md:grid-cols-[230px_minmax(0,1fr)] md:items-center lg:grid-cols-[300px_minmax(0,1fr)] lg:gap-10">
          <div className="px-5 sm:px-0">
            <p className="inline-flex rounded-full bg-[#eee8ff] px-4 py-2 text-[11px] font-extrabold uppercase tracking-[.12em] text-[#6041cc]">Jobs hiring now</p>
            <h2 id="hot-jobs-heading" className="mt-5 text-[2rem] font-extrabold leading-[1.08] tracking-[-.035em] text-[#160847] lg:text-[2.55rem]">Hot job requirements near you</h2>
            <p className="mt-4 text-[15px] leading-7 text-[#675d79] lg:text-base">Trending jobs in your city and nearby locations</p>
            {!compact ? <Link className="focus-ring mt-6 inline-flex min-h-12 items-center justify-center gap-3 rounded-lg bg-[#160847] px-5 py-3 text-sm font-bold text-white transition hover:bg-[#2b146d]" href={routes.jobs}>View all jobs <span aria-hidden="true">→</span></Link> : null}
          </div>
          <HotJobsCarousel jobs={jobs} />
        </div>
      </div>
    </section>
  );
}
