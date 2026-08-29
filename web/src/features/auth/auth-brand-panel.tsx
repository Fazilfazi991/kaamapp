import type { AppAccountRole, AuthMode } from "@/lib/auth/routing";

type AuthBrandPanelProps = {
  mode: AuthMode;
  role: AppAccountRole;
};

const roleContent = {
  candidate: {
    title: "Your next opportunity starts with a profile that shows what you can do.",
    description: "Build one clear candidate profile, control your information, and hear from employers looking for your skills.",
    benefits: ["Show your skills and experience clearly", "Review employer interest before connecting", "Keep private details protected"],
  },
  employer: {
    title: "Find people whose skills fit the work you need done.",
    description: "Create your employer workspace, define your requirements, and connect after genuine mutual interest.",
    benefits: ["Create a trusted company presence", "Search candidates by relevant requirements", "Manage interest and matches in one place"],
  },
} as const;

export function AuthBrandPanel({ mode, role }: AuthBrandPanelProps) {
  const isRegister = mode === "register";
  const content = roleContent[role];

  return (
    <aside className="relative overflow-hidden rounded-3xl border border-[#e5dff4] bg-white/80 p-4 shadow-[0_18px_48px_rgba(22,8,71,.08)] sm:p-7 lg:min-h-[540px] lg:p-9">
      <div className="pointer-events-none absolute -right-16 -top-16 h-44 w-44 rounded-full bg-[#f4f1ff]" />
      <div className="pointer-events-none absolute -bottom-20 -left-16 h-48 w-48 rounded-full border-[22px] border-[#f7f5ff]" />
      <div className="relative flex h-full flex-col">
        <div className="max-w-md pt-2 sm:pt-3 lg:pt-5">
          <h2 className="mt-3 text-2xl font-bold tracking-tight text-[#160847] sm:text-4xl">
            {content.title}
          </h2>
          <p className="mt-4 max-w-lg text-sm leading-6 text-[#6b6071] sm:text-base">
            {content.description}
          </p>
        </div>

        <ul className="mt-5 grid gap-3 sm:mt-6" aria-label="KAAM benefits">
          {content.benefits.map((benefit, index) => (
            <li key={benefit} className="flex items-center gap-3 text-sm font-medium leading-5 text-[#3c3441]">
              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#f0edfb] text-[#160847]" aria-hidden="true">
                <BenefitIcon index={index} />
              </span>
              {benefit}
            </li>
          ))}
        </ul>

        <div className="mt-7 hidden rounded-2xl border border-[#e5dff4] bg-[#fcfbff] p-4 shadow-sm lg:block">
          <div className="flex items-center justify-between gap-3">
            <MiniProfile label="Profile" tone="pink" />
            <span className="h-px flex-1 bg-[#cfc4f1]" />
            <MiniProfile label="Match" tone="dark" />
            <span className="h-px flex-1 bg-[#cfc4f1]" />
            <MiniProfile label="Connect" tone="pink" />
          </div>
          <p className="mt-4 text-center text-xs font-semibold text-[#6b6071]">Built for faster hiring across the UAE</p>
        </div>

        <p className="mt-4 border-t border-[#eee9ff] pt-3 text-xs font-semibold text-[#6b6071] lg:mt-auto lg:pt-4">
          {isRegister ? "Register" : "Sign in"} <span className="px-1 text-[#f56ba1]">→</span> {role === "candidate" ? "Build your profile" : "Set up your company"} <span className="px-1 text-[#f56ba1]">→</span> Connect
        </p>
      </div>
    </aside>
  );
}

function MiniProfile({ label, tone }: { label: string; tone: "pink" | "dark" }) {
  return (
    <div className="grid justify-items-center gap-1.5 text-center">
      <span className={`grid h-10 w-10 place-items-center rounded-xl ${tone === "pink" ? "bg-[#f0edfb] text-[#160847]" : "bg-[#160847] text-white"}`} aria-hidden="true">
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
