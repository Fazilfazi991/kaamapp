import Image from "next/image";
import type { ReactNode } from "react";
import { signOutAction } from "@/lib/auth/session";
import { Button } from "@/components/ui/button";
import { ActiveDashboardLink } from "./active-dashboard-link";

export function DashboardSidebar({
  items,
  title,
  account,
}: {
  items: Array<{ href: string; label: string }>;
  title: string;
  account?: { email: string | null; role: string; name?: string | null };
}) {
  return (
    <aside className="hidden min-h-screen w-[260px] flex-col border-r border-[#eadde3] bg-white p-4 lg:flex">
      <div className="inline-flex rounded-lg bg-[#342b38] px-3 py-2 shadow-sm">
        <Image src="/kaam-logo.webp" alt="Kaam" width={116} height={46} priority />
      </div>
      <p className="mt-6 text-xs font-semibold uppercase tracking-[0.16em] text-[#8a7c88]">
        {title}
      </p>
      <nav className="mt-3 grid gap-1" aria-label={`${title} navigation`}>
        {items.map((item) => (
          <ActiveDashboardLink
            key={item.href}
            href={item.href}
            label={item.label}
            leading={<NavIcon label={item.label} />}
            className="focus-ring flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold text-[#3b3340] hover:bg-[#fff0f5] hover:text-[#bc1f55]"
            activeClassName="bg-[#fff0f5] text-[#bc1f55]"
          />
        ))}
      </nav>
      {account ? <div className="mt-auto border-t border-[#f0e4e9] pt-4"><div className="flex items-center gap-3 rounded-xl bg-[#fffafd] p-3"><span className="grid h-9 w-9 place-items-center rounded-full bg-[#342b38] text-xs font-bold text-white">{initials(account.name ?? account.email)}</span><div className="min-w-0"><p className="truncate text-sm font-bold text-[#302934]">{account.name || "KAAM account"}</p><p className="truncate text-xs text-[#746975]">{title}</p></div></div></div> : null}
      <form action={signOutAction} className="pt-4">
        <Button type="submit" variant="secondary" className="w-full">
          Logout
        </Button>
      </form>
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
