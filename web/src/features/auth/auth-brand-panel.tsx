import Image from "next/image";

type AuthBrandPanelProps = {
  mode: "login" | "register";
};

const benefits = [
  "Verified candidate & employer profiles",
  "Smart matching built around real requirements",
  "Direct interest and meaningful connections",
];

export function AuthBrandPanel({ mode }: AuthBrandPanelProps) {
  const isRegister = mode === "register";

  return (
    <aside className="relative overflow-hidden rounded-3xl border border-[#f2dce6] bg-white/80 p-4 shadow-[0_18px_48px_rgba(92,39,62,.08)] sm:p-7 lg:min-h-[540px] lg:p-9">
      <div className="pointer-events-none absolute -right-16 -top-16 h-44 w-44 rounded-full bg-[#fff0f6]" />
      <div className="pointer-events-none absolute -bottom-20 -left-16 h-48 w-48 rounded-full border-[22px] border-[#fff4f8]" />
      <div className="relative flex h-full flex-col">
        <div className="inline-flex w-fit items-center justify-start">
          <Image src="/kaam-original-logo.png" alt="KAAM Perfect Match" width={112} height={50} priority className="h-auto w-[112px]" />
        </div>

        <div className="mt-4 max-w-md sm:mt-6 lg:mt-9">
          <p className="text-xs font-bold uppercase tracking-[.18em] text-[#f56ba1]">Recruitment, made mutual</p>
          <h2 className="mt-3 text-2xl font-bold tracking-tight text-[#160847] sm:text-4xl">
            {isRegister ? "Start your KAAM journey." : "Find the right opportunity. Faster."}
          </h2>
          <p className="mt-4 max-w-lg text-sm leading-6 text-[#6b6071] sm:text-base">
            KAAM connects candidates and employers through verified profiles, matching, and direct opportunities.
          </p>
        </div>

        <ul className="mt-4 grid gap-2 sm:mt-6 sm:gap-3" aria-label="KAAM benefits">
          {benefits.map((benefit, index) => (
            <li key={benefit} className="flex items-center gap-3 text-sm font-medium text-[#3c3441]">
              <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-[#fce1ec] text-[#160847]" aria-hidden="true">
                <BenefitIcon index={index} />
              </span>
              {benefit}
            </li>
          ))}
        </ul>

        <div className="mt-7 hidden rounded-2xl border border-[#f2dce6] bg-[#fffafd] p-4 shadow-sm lg:block">
          <div className="flex items-center justify-between gap-3">
            <MiniProfile label="Profile" tone="pink" />
            <span className="h-px flex-1 bg-[#efb5ca]" />
            <MiniProfile label="Match" tone="dark" />
            <span className="h-px flex-1 bg-[#efb5ca]" />
            <MiniProfile label="Connect" tone="pink" />
          </div>
          <p className="mt-4 text-center text-xs font-semibold text-[#6b6071]">Built for faster hiring across the UAE</p>
        </div>

        <p className="mt-4 border-t border-[#f4e4eb] pt-3 text-xs font-semibold text-[#6b6071] lg:mt-auto lg:pt-4">
          Profile <span className="px-1 text-[#e53670]">→</span> Match <span className="px-1 text-[#e53670]">→</span> Connect
        </p>
      </div>
    </aside>
  );
}

function MiniProfile({ label, tone }: { label: string; tone: "pink" | "dark" }) {
  return (
    <div className="grid justify-items-center gap-1.5 text-center">
      <span className={`grid h-10 w-10 place-items-center rounded-xl ${tone === "pink" ? "bg-[#ffe7f0] text-[#e53670]" : "bg-[#342b38] text-white"}`} aria-hidden="true">
        <span className="h-3 w-3 rounded-full border-2 border-current" />
      </span>
      <span className="text-[11px] font-bold text-[#423946]">{label}</span>
    </div>
  );
}

function BenefitIcon({ index }: { index: number }) {
  const paths = [
    <><path d="M12 3 19 6v5.3c0 4.4-2.8 7.5-7 9.7-4.2-2.2-7-5.3-7-9.7V6l7-3Z" /><path d="m9 12 2 2 4-4" /></>,
    <><circle cx="9" cy="9" r="3" /><circle cx="17" cy="10" r="2" /><path d="M3.5 20c.6-3.1 2.5-4.8 5.5-4.8s4.9 1.7 5.5 4.8M14.5 16c3 0 4.9 1.4 5.5 4" /></>,
    <><path d="m3 11 18-8-7.5 18-3-7L3 11Z" /><path d="m10.5 14 4.2-4.1" /></>,
  ];

  return <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">{paths[index]}</svg>;
}
