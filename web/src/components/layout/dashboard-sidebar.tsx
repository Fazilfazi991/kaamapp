import Image from "next/image";
import { signOutAction } from "@/lib/auth/session";
import { Button } from "@/components/ui/button";
import { ActiveDashboardLink } from "./active-dashboard-link";

export function DashboardSidebar({
  items,
  title,
}: {
  items: Array<{ href: string; label: string }>;
  title: string;
}) {
  return (
    <aside className="hidden min-h-screen w-64 border-r border-[#eadde3] bg-white p-5 lg:block">
      <Image src="/kaam-logo.webp" alt="Kaam" width={116} height={46} priority />
      <p className="mt-6 text-xs font-semibold uppercase tracking-[0.16em] text-[#8a7c88]">
        {title}
      </p>
      <nav className="mt-3 grid gap-1" aria-label={`${title} navigation`}>
        {items.map((item) => (
          <ActiveDashboardLink
            key={item.href}
            href={item.href}
            label={item.label}
            className="focus-ring rounded-lg px-3 py-3 text-sm font-semibold text-[#3b3340] hover:bg-[#fff0f5] hover:text-[#bc1f55]"
            activeClassName="bg-[#fff0f5] text-[#bc1f55]"
          />
        ))}
      </nav>
      <form action={signOutAction} className="mt-8">
        <Button type="submit" variant="secondary" className="w-full">
          Logout
        </Button>
      </form>
    </aside>
  );
}
