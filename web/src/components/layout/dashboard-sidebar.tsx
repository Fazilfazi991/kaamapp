import Image from "next/image";
import type { ReactNode } from "react";
import { LogoutButton } from "@/features/auth/logout-button";
import { ActiveDashboardLink } from "./active-dashboard-link";

export function DashboardSidebar({
  items,
  title,
  account,
}: {
  items: Array<{ href: string; label: string; prefetch?: boolean }>;
  title: string;
  account?: { email: string | null; role: string; name?: string | null };
}) {
  return (
    <aside className="hidden min-h-screen w-[264px] flex-col border-r border-[#e7e1f2] bg-white lg:flex">
      <div className="flex h-24 items-center justify-center bg-[#160847] px-6 shadow-sm">
        <Image src="/kaam-original-logo.png" alt="KAAM Perfect Match" width={132} height={58} priority className="h-auto w-[132px] object-contain" />
      </div>
      <div className="flex min-h-0 flex-1 flex-col px-4 pb-4 pt-5">
      <p className="px-3 text-[11px] font-bold uppercase tracking-[0.18em] text-[#756b8a]">
        {title}
      </p>
      <nav className="mt-3 grid gap-1" aria-label={`${title} navigation`}>
        {items.map((item) => (
          <ActiveDashboardLink
            key={item.href}
            href={item.href}
            label={item.label}
            prefetch={item.prefetch}
            leading={<NavIcon label={item.label} />}
            className="focus-ring flex min-h-11 items-center gap-3 rounded-xl px-3 text-sm font-semibold text-[#3b3340] hover:bg-[#f3f0ff] hover:text-[#160847]"
            activeClassName="bg-[#160847] text-white shadow-[0_4px_12px_rgba(22,8,71,.16)]"
          />
        ))}
      </nav>
      <div className="mt-auto">
      {account ? <div className="border-t border-[#eee9ff] pt-4"><div className="flex items-center gap-3 rounded-xl bg-[#faf9ff] p-3"><span className="grid h-9 w-9 place-items-center rounded-full bg-[#160847] text-xs font-bold text-white">{initials(account.name ?? account.email)}</span><div className="min-w-0"><p className="truncate text-sm font-bold text-[#160847]">{account.name || "KAAM account"}</p><p className="truncate text-xs text-[#746975]">{title}</p></div></div></div> : null}
      <LogoutButton variant="secondary" className={account ? "pt-3" : "border-t border-[#eee9ff] pt-4"} />
      </div>
      </div>
    </aside>
  );
}

function initials(value?: string | null) {
  return (value ?? "K").split(/\s+|@/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "K";
}

function NavIcon({ label }: { label: string }) {
  const common = { width: 19, height: 19, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const, "aria-hidden": true };
  const icons: Record<string, ReactNode> = {
    Dashboard: <><path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z" /></>,
    Profile: <><circle cx="12" cy="8" r="3.5" /><path d="M4.5 20c.9-3.5 3.3-5.3 7.5-5.3s6.6 1.8 7.5 5.3" /></>,
    "Complete profile": <><circle cx="12" cy="12" r="8" /><path d="m8.5 12 2.3 2.4 4.7-4.8" /></>,
    Interests: <><path d="m4 12 12-8v16z" /><path d="M16 8h4v8h-4" /></>,
    Matches: <path d="M20.8 5.8a5.2 5.2 0 0 0-7.4 0L12 7.2l-1.4-1.4a5.2 5.2 0 0 0-7.4 7.4L12 22l8.8-8.8a5.2 5.2 0 0 0 0-7.4Z" />,
    Messages: <><path d="M20 11.5a7.5 7.5 0 0 1-8 7.5 9 9 0 0 1-3-.5L4 20l1.4-4A7.4 7.4 0 0 1 4 11.5 7.6 7.6 0 0 1 12 4a7.6 7.6 0 0 1 8 7.5Z" /></>,
    Notifications: <><path d="M18 9a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9" /><path d="M10 22h4" /></>,
    Documents: <><path d="M7 3h7l4 4v14H7z" /><path d="M14 3v5h5" /></>,
    Membership: <><path d="M12 3 19 6v5.3c0 4.4-2.8 7.5-7 9.7-4.2-2.2-7-5.3-7-9.7V6l7-3Z" /><path d="M12 8v7M8.5 11.5h7" /></>,
  };
  return <svg {...common}>{icons[label] ?? <circle cx="12" cy="12" r="7" />}</svg>;
}
