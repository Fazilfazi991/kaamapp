import Link from "next/link";

import { ButtonLink } from "@/components/ui/button";
import { routes } from "@/config/routes";

type IconProps = { className?: string };

function BriefcaseIcon({ className = "" }: IconProps) {
  return (
    <svg aria-hidden="true" className={className} fill="none" viewBox="0 0 24 24">
      <path d="M8 7V5.7A2.7 2.7 0 0 1 10.7 3h2.6A2.7 2.7 0 0 1 16 5.7V7M4.5 8h15A1.5 1.5 0 0 1 21 9.5v9A1.5 1.5 0 0 1 19.5 20h-15A1.5 1.5 0 0 1 3 18.5v-9A1.5 1.5 0 0 1 4.5 8Z" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.8" />
      <path d="M3 12.25h7.1m3.8 0H21M10.1 10.75h3.8v3h-3.8v-3Z" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.8" />
    </svg>
  );
}

function PeopleIcon({ className = "" }: IconProps) {
  return (
    <svg aria-hidden="true" className={className} fill="none" viewBox="0 0 24 24">
      <circle cx="9" cy="7.25" r="3.25" stroke="currentColor" strokeWidth="1.8" />
      <path d="M3 20v-1.25a6 6 0 0 1 12 0V20M16.25 5.25a3 3 0 0 1 0 5.75M17 13.25a5.25 5.25 0 0 1 4 5.1V20" stroke="currentColor" strokeLinecap="round" strokeWidth="1.8" />
    </svg>
  );
}

function CheckIcon({ className = "" }: IconProps) {
  return (
    <svg aria-hidden="true" className={className} fill="none" viewBox="0 0 16 16">
      <path d="m4 8.25 2.5 2.5L12 5.5" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" />
    </svg>
  );
}

function ShieldIcon({ className = "" }: IconProps) {
  return (
    <svg aria-hidden="true" className={className} fill="none" viewBox="0 0 24 24">
      <path d="m12 3 7 3v5c0 4.7-2.65 8.05-7 10-4.35-1.95-7-5.3-7-10V6l7-3Z" stroke="currentColor" strokeLinejoin="round" strokeWidth="1.8" />
      <path d="m8.75 12 2.1 2.1 4.4-4.5" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.8" />
    </svg>
  );
}

function BadgeIcon({ className = "" }: IconProps) {
  return (
    <svg aria-hidden="true" className={className} fill="none" viewBox="0 0 24 24">
      <path d="m12 3 2 1.2 2.35-.15 1.05 2.1 2.05 1.2-.15 2.35 1.2 2-1.2 2 .15 2.35-2.05 1.2-1.05 2.1L14 18l-2 1.2-2-1.2-2.35.15-1.05-2.1-2.05-1.2.15-2.35-1.2-2 1.2-2-.15-2.35 2.05-1.2 1.05-2.1L10 4.2 12 3Z" stroke="currentColor" strokeLinejoin="round" strokeWidth="1.65" />
      <path d="m8.9 11.9 2 2 4.2-4.35M9 18.05 8 22l4-2 4 2-1-3.95" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.65" />
    </svg>
  );
}

const benefits = {
  candidate: ["Create profile", "Get discovered by top employers"],
  employer: ["Post roles in minutes", "Find verified candidates"],
} as const;

const trustItems = [
  { title: "Secure & Private", text: "Your data is protected", Icon: ShieldIcon },
  { title: "Verified Employers", text: "Trusted opportunities", Icon: BadgeIcon },
  { title: "Smart Matching", text: "Better connections", Icon: PeopleIcon },
] as const;

function BenefitList({ items, tone }: { items: readonly string[]; tone: "candidate" | "employer" }) {
  return (
    <ul className="grid gap-3.5 sm:gap-4">
      {items.map((item) => (
        <li className="flex items-center gap-3 text-sm font-medium text-[#594f61] sm:text-[15px]" key={item}>
          <span className={`grid h-5 w-5 shrink-0 place-items-center rounded-full text-white ${tone === "candidate" ? "bg-[#f56ba1]" : "bg-[#8055cf]"}`}>
            <CheckIcon className="h-3.5 w-3.5" />
          </span>
          {item}
        </li>
      ))}
    </ul>
  );
}

function LoginLink({ href, children, tone }: { href: string; children: string; tone: "candidate" | "employer" }) {
  return (
    <Link href={href} className="focus-ring group relative inline-block rounded-sm pb-1 font-bold text-[#160847]">
      {children}
      <svg aria-hidden="true" className={`absolute -bottom-0.5 left-0 h-1.5 w-full overflow-visible ${tone === "candidate" ? "text-[#f56ba1]" : "text-[#8b5bd4]"}`} preserveAspectRatio="none" viewBox="0 0 100 6">
        <path d="M1 2.25 Q50 5.5 99 2.25" fill="none" stroke="currentColor" strokeLinecap="round" strokeWidth="1.5" vectorEffect="non-scaling-stroke" />
      </svg>
    </Link>
  );
}

export function RoleEntrySection() {
  return (
    <section className="overflow-hidden bg-[linear-gradient(135deg,#fffdfd_0%,#fff7fa_52%,#fbf8ff_100%)] px-3 py-8 sm:px-6 sm:py-12 lg:px-8 lg:py-14" aria-labelledby="role-entry-heading">
      <div className="mx-auto max-w-6xl">
        <header className="mx-auto max-w-3xl text-center">
          <p className="inline-flex rounded-full border border-[#f7cddd] bg-[#fff0f6] px-4 py-1.5 text-[11px] font-bold uppercase tracking-[0.12em] text-[#df3778] sm:px-5 sm:text-xs">
            KAAM connects
          </p>
          <h1 id="role-entry-heading" className="mt-4 text-[2rem] font-extrabold leading-[1.05] tracking-[-.035em] text-[#160847] sm:mt-5 sm:text-5xl lg:text-[3.5rem]">
            Connect. Create. Grow.
          </h1>
          <p className="mx-auto mt-4 max-w-2xl text-[15px] leading-6 text-[#5f5669] sm:mt-5 sm:text-lg sm:leading-8">
            KAAM connects workers and employers based on skills, requirements and mutual interest.
          </p>
        </header>

        <div className="mt-7 grid gap-4 md:mt-10 md:grid-cols-2 md:gap-6 lg:gap-8">
          <article className="flex min-w-0 flex-col rounded-2xl border border-[#f2cad9] bg-white p-5 shadow-[0_12px_34px_rgba(83,35,60,.055)] sm:p-7 lg:p-9">
            <div className="flex items-start gap-4 sm:block">
              <span className="grid h-14 w-14 shrink-0 place-items-center rounded-full bg-[#ffe6f0] text-[#e83f81] sm:h-16 sm:w-16">
                <BriefcaseIcon className="h-7 w-7 sm:h-8 sm:w-8" />
              </span>
              <div className="min-w-0 sm:mt-6">
                <h2 className="text-2xl font-extrabold leading-tight tracking-[-.025em] text-[#160847] sm:text-[2rem]">Looking for a job?</h2>
                <p className="mt-1.5 text-sm leading-6 text-[#655b68] sm:mt-3 sm:text-base">Create your KAAM profile and get discovered by employers.</p>
              </div>
            </div>
            <div className="my-5 border-t border-[#f4d9e4] sm:my-6" />
            <BenefitList items={benefits.candidate} tone="candidate" />
            <div className="mt-auto pt-6 sm:pt-8">
              <ButtonLink href={routes.candidateRegister} className="min-h-13 w-full text-base shadow-[0_10px_22px_rgba(22,8,71,.12)]">
                Register as Candidate
              </ButtonLink>
              <p className="mt-4 text-center text-[13px] leading-5 text-[#655b68] sm:text-sm">
                Already registered?{" "}
                <LoginLink href={routes.candidateLogin} tone="candidate">Candidate Login</LoginLink>
              </p>
            </div>
          </article>

          <article className="flex min-w-0 flex-col rounded-2xl border border-[#dcd0f1] bg-white p-5 shadow-[0_12px_34px_rgba(48,30,91,.05)] sm:p-7 lg:p-9">
            <div className="flex items-start gap-4 sm:block">
              <span className="grid h-14 w-14 shrink-0 place-items-center rounded-full bg-[#eee6ff] text-[#6632bd] sm:h-16 sm:w-16">
                <PeopleIcon className="h-7 w-7 sm:h-8 sm:w-8" />
              </span>
              <div className="min-w-0 sm:mt-6">
                <h2 className="text-2xl font-extrabold leading-tight tracking-[-.025em] text-[#160847] sm:text-[2rem]">Hiring workers?</h2>
                <p className="mt-1.5 text-sm leading-6 text-[#655b68] sm:mt-3 sm:text-base">Find suitable candidates for your business.</p>
              </div>
            </div>
            <div className="my-5 border-t border-[#e7ddf5] sm:my-6" />
            <BenefitList items={benefits.employer} tone="employer" />
            <div className="mt-auto pt-6 sm:pt-8">
              <ButtonLink href={routes.employerRegister} variant="secondary" className="min-h-13 w-full border-2 text-base">
                Register as Employer
              </ButtonLink>
              <p className="mt-4 text-center text-[13px] leading-5 text-[#655b68] sm:text-sm">
                Already have an employer account?{" "}
                <LoginLink href={routes.employerLogin} tone="employer">Employer Login</LoginLink>
              </p>
            </div>
          </article>
        </div>

        <div className="mt-5 grid grid-cols-3 divide-x divide-[#e4dbe9] rounded-2xl border border-[#e8ddeb] bg-white/80 px-1.5 py-4 sm:mt-8 sm:px-4 sm:py-5 lg:px-8" aria-label="KAAM trust benefits">
          {trustItems.map(({ title, text, Icon }) => (
            <div className="flex min-w-0 flex-col items-center gap-2 px-1 text-center sm:flex-row sm:justify-center sm:gap-3 sm:px-4 sm:text-left" key={title}>
              <span className="grid h-8 w-8 shrink-0 place-items-center text-[#160847] sm:h-10 sm:w-10">
                <Icon className="h-6 w-6 sm:h-7 sm:w-7" />
              </span>
              <span className="min-w-0">
                <strong className="block text-[10px] font-bold leading-[1.25] text-[#160847] sm:text-sm">{title}</strong>
                <span className="mt-0.5 block text-[9px] leading-[1.3] text-[#6d6373] sm:text-xs">{text}</span>
              </span>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
