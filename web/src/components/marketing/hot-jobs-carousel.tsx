"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import { routes } from "@/config/routes";
import { publicRequirementTitle, type PublicHiringRequirement } from "@/features/public-jobs/types";

function Arrow({ direction }: { direction: "left" | "right" }) {
  return (
    <svg aria-hidden="true" className="h-5 w-5" fill="none" viewBox="0 0 24 24">
      <path d={direction === "left" ? "m15 18-6-6 6-6" : "m9 6 6 6-6 6"} stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" />
    </svg>
  );
}

function formatDeadline(value: string) {
  return new Intl.DateTimeFormat("en-GB", { day: "2-digit", month: "short", year: "numeric", timeZone: "UTC" }).format(new Date(`${value}T00:00:00Z`));
}

function registrationHref(id: string) {
  const destination = `${routes.candidateJobs}?requirement=${encodeURIComponent(id)}`;
  return `${routes.candidateRegister}?redirectTo=${encodeURIComponent(destination)}`;
}

export function HotJobsCarousel({ jobs }: { jobs: PublicHiringRequirement[] }) {
  const scroller = useRef<HTMLDivElement>(null);
  const [activeIndex, setActiveIndex] = useState(0);
  const [paused, setPaused] = useState(false);

  function scrollTo(index: number) {
    const element = scroller.current;
    if (!element) return;
    const cards = element.querySelectorAll<HTMLElement>("[data-job-card]");
    const target = cards[index];
    if (!target) return;
    element.scrollTo({ left: target.offsetLeft - element.offsetLeft, behavior: "smooth" });
    setActiveIndex(index);
  }

  function move(delta: number) {
    scrollTo((activeIndex + delta + jobs.length) % jobs.length);
  }

  useEffect(() => {
    if (paused || jobs.length < 2 || window.matchMedia("(max-width: 767px), (prefers-reduced-motion: reduce)").matches) return;
    const timer = window.setInterval(() => move(1), 5000);
    return () => window.clearInterval(timer);
  });

  return (
    <div className="min-w-0 md:pt-1" onMouseEnter={() => setPaused(true)} onMouseLeave={() => setPaused(false)} onFocusCapture={() => setPaused(true)} onBlurCapture={() => setPaused(false)}>
      <div
        ref={scroller}
        className="hot-jobs-scroller flex snap-x snap-mandatory gap-4 overflow-x-auto px-5 pb-4 pt-1 [scrollbar-width:none] sm:px-6 md:px-1"
        aria-label="Current job requirements"
        onScroll={(event) => {
          const cards = event.currentTarget.querySelectorAll<HTMLElement>("[data-job-card]");
          let nearest = 0;
          let distance = Number.POSITIVE_INFINITY;
          cards.forEach((card, index) => {
            const nextDistance = Math.abs(card.offsetLeft - event.currentTarget.offsetLeft - event.currentTarget.scrollLeft);
            if (nextDistance < distance) { nearest = index; distance = nextDistance; }
          });
          setActiveIndex(nearest);
        }}
      >
        {jobs.map((job) => (
          <article data-job-card className="flex min-h-[300px] w-[82vw] max-w-[310px] shrink-0 snap-start flex-col rounded-2xl bg-white p-5 shadow-[0_10px_28px_rgba(40,23,91,.09)] md:w-[250px] md:max-w-none md:p-6" key={job.id}>
            <h3 className="text-[19px] font-extrabold leading-6 tracking-[-.02em] text-[#160847]">{publicRequirementTitle(job)}</h3>
            <p className="mt-2 text-sm leading-5 text-[#675d79]">{job.work_location}</p>
            <div className="my-6 h-px bg-[#eee9f8]" />
            <div className="grid grid-cols-[.8fr_1.2fr] items-end gap-3">
              <div>
                <strong className="block text-[28px] font-extrabold leading-none tabular-nums text-[#5631c5]">{job.openings}</strong>
                <span className="mt-1.5 block text-xs text-[#675d79]">{job.openings === 1 ? "vacancy" : "vacancies"}</span>
              </div>
              <div className="border-l border-[#eee9f8] pl-4">
                <span className="block text-xs text-[#675d79]">Apply before</span>
                <strong className="mt-1.5 block text-sm font-bold leading-5 tabular-nums text-[#5631c5]">{formatDeadline(job.application_deadline)}</strong>
              </div>
            </div>
            <Link className="focus-ring mt-auto inline-flex min-h-12 w-full items-center justify-center rounded-lg bg-[#160847] px-4 py-3 text-sm font-bold text-white transition hover:bg-[#2b146d]" href={registrationHref(job.id)}>
              Register now
            </Link>
          </article>
        ))}
      </div>

      <div className="mt-1 hidden items-center justify-center gap-4 md:flex">
        <button className="focus-ring grid h-11 w-11 place-items-center rounded-full bg-[#e9e2fb] text-[#5631c5] transition hover:bg-[#ddd2f7]" type="button" aria-label="Previous jobs" onClick={() => move(-1)}><Arrow direction="left" /></button>
        <div className="flex items-center gap-2" aria-label={`Job ${activeIndex + 1} of ${jobs.length}`}>
          {jobs.map((job, index) => <button type="button" aria-label={`Go to job ${index + 1}`} aria-current={index === activeIndex ? "true" : undefined} onClick={() => scrollTo(index)} className={`focus-ring rounded-full transition-all ${index === activeIndex ? "h-2.5 w-2.5 bg-[#5631c5]" : "h-2 w-2 bg-[#cfc5e8] hover:bg-[#a995da]"}`} key={job.id} />)}
        </div>
        <button className="focus-ring grid h-11 w-11 place-items-center rounded-full bg-[#e9e2fb] text-[#5631c5] transition hover:bg-[#ddd2f7]" type="button" aria-label="Next jobs" onClick={() => move(1)}><Arrow direction="right" /></button>
      </div>
      <p className="mt-1 text-center text-xs font-medium text-[#675d79] md:hidden"><span className="text-[#f56ba1]">←</span> Swipe to explore more jobs <span className="text-[#f56ba1]">→</span></p>
    </div>
  );
}
