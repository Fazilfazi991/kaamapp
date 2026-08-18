"use client";

import Image from "next/image";
import { useState } from "react";

type IconName = "user" | "star" | "shield" | "people" | "building" | "search" | "send" | "chat" | "trophy" | "bolt" | "heart";
type Step = { title: string; description: string; icon: IconName };

const candidateSteps: Step[] = [
  { title: "Create profile", description: "Build your profile and showcase your experience.", icon: "user" },
  { title: "Select skills", description: "Add your skills and highlight what you do best.", icon: "star" },
  { title: "Complete verification", description: "Verify your identity and build trust.", icon: "shield" },
  { title: "Get matched with employers", description: "Get matched with the right opportunities.", icon: "people" },
];

const employerSteps: Step[] = [
  { title: "Create company profile", description: "Set up your company profile and tell us what you need.", icon: "building" },
  { title: "Search workers", description: "Search and filter workers that match your needs.", icon: "search" },
  { title: "Send interest", description: "Show interest in the right profiles.", icon: "send" },
  { title: "Connect after matching", description: "Connect and start a conversation.", icon: "chat" },
];

const benefits: Array<{ icon: IconName; title: string; text: string }> = [
  { icon: "shield", title: "Trusted & Verified", text: "Safe and transparent platform." },
  { icon: "people", title: "Smart Matching", text: "Relevant matches based on real requirements." },
  { icon: "bolt", title: "Faster Connections", text: "From interest to conversation quickly." },
  { icon: "heart", title: "Better Outcomes", text: "Better opportunities and better hiring." },
];

export function HowItWorks() {
  const [audience, setAudience] = useState<"candidate" | "employer">("candidate");
  const activeSteps = audience === "candidate" ? candidateSteps : employerSteps;

  return (
    <section className="relative overflow-hidden bg-gradient-to-b from-white via-[#fffafd] to-[#fff5f9] py-8 sm:py-9" aria-labelledby="how-it-works-heading">
      <div className="pointer-events-none absolute left-5 top-28 hidden h-4 w-4 rotate-45 bg-[#ff82b0] lg:block" />
      <div className="pointer-events-none absolute right-12 top-44 hidden text-4xl text-[#ff82b0] lg:block">✦</div>
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <h2 id="how-it-works-heading" className="sr-only">How KAAM works</h2>

        <div className="hidden lg:grid lg:grid-cols-[minmax(0,1fr)_310px_minmax(0,1fr)] lg:items-center lg:gap-5 xl:grid-cols-[minmax(0,1fr)_340px_minmax(0,1fr)] xl:gap-6">
          <Journey title="How candidates use Kaam" subtitle="Simple steps to get noticed and hired" steps={candidateSteps} side="left" />
          <Hub />
          <Journey title="How employers use Kaam" subtitle="Find talent and build your team" steps={employerSteps} side="right" />
        </div>

        <div className="lg:hidden">
          <div className="text-center">
            <p className="text-sm font-bold uppercase tracking-[.18em] text-[#d91f64]">Recruitment, made mutual</p>
            <h3 className="mt-2 text-3xl font-bold tracking-tight text-[#17172d]">How KAAM works</h3>
          </div>
          <div className="mx-auto mt-7 grid max-w-md grid-cols-2 rounded-xl border border-[#f2cddd] bg-white p-1 shadow-sm" role="tablist" aria-label="Choose a KAAM journey">
            <button type="button" role="tab" aria-selected={audience === "candidate"} onClick={() => setAudience("candidate")} className={`rounded-lg px-4 py-3 text-sm font-bold transition ${audience === "candidate" ? "bg-[#e53670] text-white shadow-sm" : "text-[#5d5364]"}`}>For Candidates</button>
            <button type="button" role="tab" aria-selected={audience === "employer"} onClick={() => setAudience("employer")} className={`rounded-lg px-4 py-3 text-sm font-bold transition ${audience === "employer" ? "bg-[#e53670] text-white shadow-sm" : "text-[#5d5364]"}`}>For Employers</button>
          </div>
          <div className="mx-auto mt-7 max-w-xl">
            <p className="mb-4 text-center text-sm text-[#6b6071]">{audience === "candidate" ? "Simple steps to get noticed and hired" : "Find talent and build your team"}</p>
            <div className="relative space-y-4 before:absolute before:bottom-7 before:left-7 before:top-7 before:border-l-2 before:border-dashed before:border-[#f7b4cb]">
              {activeSteps.map((step, index) => <StepCard key={step.title} step={step} index={index} />)}
            </div>
          </div>
        </div>

        <div className="relative mt-2 hidden h-36 lg:block xl:h-40" aria-hidden="true">
          <Image src="/kaam/how-it-works/candidate-illustration.png" alt="" width={230} height={230} className="absolute bottom-0 left-0 h-32 w-auto object-contain xl:h-36" />
          <Image src="/kaam/how-it-works/employer-illustration.png" alt="" width={250} height={250} className="absolute bottom-0 right-0 h-32 w-auto object-contain xl:h-36" />
        </div>

        <div className="relative z-10 mt-3 grid gap-2 rounded-2xl border border-[#f0dce5] bg-white/95 p-3 shadow-[0_8px_24px_rgba(83,37,57,.08)] sm:grid-cols-2 lg:grid-cols-4 lg:gap-0">
          {benefits.map((benefit, index) => <div key={benefit.title} className={`flex items-center gap-2 px-3 py-2.5 ${index > 0 ? "lg:border-l lg:border-[#f0e1e8]" : ""}`}><span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-[#fff0f6] text-[#e53670]"><LineIcon name={benefit.icon} size={23} /></span><div><h3 className="text-sm font-bold text-[#1b1a31]">{benefit.title}</h3><p className="mt-0.5 text-xs leading-4 text-[#706578]">{benefit.text}</p></div></div>)}
        </div>
      </div>
    </section>
  );
}

function Journey({ title, subtitle, steps, side }: { title: string; subtitle: string; steps: Step[]; side: "left" | "right" }) {
  return <div><div className={side === "right" ? "pl-2" : "pr-2"}><h3 className="text-2xl font-bold tracking-tight text-[#16152d] xl:text-3xl">{title}</h3><span className="mt-2 block h-1 w-11 rounded-full bg-[#f05b91]" /><p className="mt-2 text-base text-[#6d6376]">{subtitle}</p></div><div className="relative mt-4 space-y-3 before:absolute before:bottom-6 before:left-7 before:top-6 before:border-l-2 before:border-dashed before:border-[#f3b0c8]">{steps.map((step,index) => <StepCard key={step.title} step={step} index={index} />)}</div></div>;
}

function StepCard({ step, index }: { step: Step; index: number }) {
  return <article className="relative z-10 grid min-h-[94px] grid-cols-[64px_1fr_54px] items-center gap-2 rounded-2xl border border-[#f2e7ed] bg-white px-3 py-2.5 shadow-[0_6px_18px_rgba(50,30,46,.08)] transition duration-200 hover:-translate-y-0.5 hover:shadow-[0_10px_24px_rgba(50,30,46,.11)]"><span className="relative grid h-13 w-13 place-items-center rounded-full bg-gradient-to-br from-[#fa76a7] to-[#d80c58] text-xl font-bold text-white ring-3 ring-[#fff1f6] before:absolute before:-inset-1.5 before:rounded-full before:border before:border-dashed before:border-[#ffb2ce] before:content-['']">{index + 1}</span><div><h4 className="text-base font-bold leading-5 text-[#18172d]">{step.title}</h4><p className="mt-1 text-sm leading-5 text-[#6d6376]">{step.description}</p></div><span className="grid h-12 w-12 place-items-center rounded-xl bg-[#fff0f6] text-[#e53670]"><LineIcon name={step.icon} size={25} /></span></article>;
}

function Hub() {
  return <div className="relative flex min-h-[470px] items-center justify-center"><svg className="absolute inset-0 h-full w-full" viewBox="0 0 400 540" fill="none" aria-hidden="true"><g stroke="#ef3d79" strokeWidth="2"><path d="M0 110h55c26 0 20 140 70 140h20"/><path d="M0 230h55c26 0 20 20 70 20h20"/><path d="M0 350h55c26 0 20-100 70-100h20"/><path d="M0 470h55c26 0 20-220 70-220h20"/><path d="M400 110h-55c-26 0-20 140-70 140h-20"/><path d="M400 230h-55c-26 0-20 20-70 20h-20"/><path d="M400 350h-55c-26 0-20-100-70-100h-20"/><path d="M400 470h-55c-26 0-20-220-70-220h-20"/></g><g fill="#ef3d79">{[110,230,350,470].flatMap((cy) => [[0,cy],[400,cy]]).map(([cx,cy])=><circle key={`${cx}-${cy}`} cx={cx} cy={cy} r="4"/>)}<circle cx="145" cy="250" r="6" fill="white" stroke="#ef3d79" strokeWidth="2"/><circle cx="255" cy="250" r="6" fill="white" stroke="#ef3d79" strokeWidth="2"/></g></svg><div className="relative z-10 flex h-40 w-40 items-center justify-center rounded-full bg-[#e53670] p-8 shadow-[0_0_0_12px_rgba(229,54,112,.08),0_0_0_30px_rgba(229,54,112,.05),0_16px_32px_rgba(229,54,112,.20)] ring-2 ring-dashed ring-[#ff9dc2]"><Image src="/kaam-logo.webp" alt="KAAM" width={120} height={48} className="h-auto w-full" /></div><div className="absolute top-3 text-[#e53670]"><LineIcon name="trophy" size={46} /></div><div className="absolute bottom-1 rounded-full border border-[#f5d9e4] bg-white px-3 py-2 text-xs font-semibold text-[#302a39] shadow-sm">✓ Real people. Real opportunities.</div><div className="absolute right-7 top-14 text-base text-[#f55f95]">✦</div><div className="absolute bottom-14 left-7 text-[#f55f95]"><LineIcon name="send" size={25} /></div></div>;
}

function LineIcon({ name, size = 29 }: { name: IconName; size?: number }) {
  const common = { width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  const paths: Record<IconName, React.ReactNode> = { user:<><circle cx="12" cy="8" r="3.5"/><path d="M4.5 20c.9-3.5 3.3-5.3 7.5-5.3s6.6 1.8 7.5 5.3"/></>, star:<path d="m12 3 2.7 5.5 6.1.9-4.4 4.3 1 6.1-5.4-2.8-5.4 2.8 1-6.1-4.4-4.3 6.1-.9L12 3Z"/>, shield:<><path d="M12 3 19 6v5.3c0 4.4-2.8 7.5-7 9.7-4.2-2.2-7-5.3-7-9.7V6l7-3Z"/><path d="m9 12 2 2 4-4"/></>, people:<><circle cx="9" cy="9" r="3"/><circle cx="17" cy="10" r="2"/><path d="M3.5 20c.6-3.1 2.5-4.8 5.5-4.8s4.9 1.7 5.5 4.8M14.5 16c3 0 4.9 1.4 5.5 4"/></>, building:<><path d="M4 21h16M6 21V5h9v16M15 9h3v12M9 8h2m-2 4h2m-2 4h2"/></>, search:<><circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 4 4"/></>, send:<><path d="m3 11 18-8-7.5 18-3-7L3 11Z"/><path d="m10.5 14 4.2-4.1"/></>, chat:<><path d="M20 11.5a7.5 7.5 0 0 1-8 7.5 9 9 0 0 1-3-.5L4 20l1.4-4A7.4 7.4 0 0 1 4 11.5 7.6 7.6 0 0 1 12 4a7.6 7.6 0 0 1 8 7.5Z"/><path d="M8 12h.01M12 12h.01M16 12h.01"/></>, trophy:<><path d="M8 4h8v6a4 4 0 0 1-8 0V4Z"/><path d="M8 6H4v1a4 4 0 0 0 4 4m8-5h4v1a4 4 0 0 1-4 4M12 14v4m-4 3h8"/></>, bolt:<path d="m13 2-8 12h6l-1 8 9-13h-6l0-7Z"/>, heart:<path d="M20.8 5.8a5.2 5.2 0 0 0-7.4 0L12 7.2l-1.4-1.4a5.2 5.2 0 0 0-7.4 7.4L12 22l8.8-8.8a5.2 5.2 0 0 0 0-7.4Z"/> };
  return <svg {...common}>{paths[name]}</svg>;
}
