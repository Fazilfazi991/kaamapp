import { ActiveDashboardLink } from "./active-dashboard-link";
import { signOutAction } from "@/lib/auth/session";
import { Button } from "@/components/ui/button";

export const mobileMenuLabel = "Menu";
export const mobileMenuNavigationLabel = "Menu navigation";

export function MobileNavigation({
  items,
  variant = "default",
}: {
  items: Array<{ href: string; label: string }>;
  variant?: "candidate" | "default";
}) {
  if (variant === "candidate") {
    const primaryLabels = new Set(["Dashboard", "Interests", "Matches", "Messages", "Profile"]);
    const primary = items.filter((item) => primaryLabels.has(item.label));
    const secondary = items.filter((item) => !primaryLabels.has(item.label));
    return (
      <>
        <nav className="fixed inset-x-0 bottom-0 z-30 grid grid-cols-5 border-t border-[#eadde3] bg-white px-1 pb-[max(.25rem,env(safe-area-inset-bottom))] pt-1 shadow-[0_-8px_24px_rgba(32,25,37,0.08)] lg:hidden" aria-label="Candidate primary navigation">
          {primary.map((item) => <ActiveDashboardLink key={item.href} href={item.href} label={item.label === "Dashboard" ? "Home" : item.label} className="focus-ring flex min-h-14 flex-col items-center justify-center gap-1 rounded-lg px-1 text-[10px] font-semibold text-[#514856]" activeClassName="text-[#160847]" />)}
        </nav>
        <details className="fixed bottom-[4.8rem] right-3 z-30 lg:hidden">
          <summary className="focus-ring cursor-pointer list-none rounded-full border border-[#eadde3] bg-white px-4 py-2 text-xs font-bold text-[#413946] shadow-lg">More</summary>
          <div className="absolute bottom-[calc(100%+.5rem)] right-0 grid w-56 gap-1 rounded-2xl border border-[#eadde3] bg-white p-2 shadow-xl"><nav aria-label={mobileMenuNavigationLabel}>{secondary.map((item) => <ActiveDashboardLink key={item.href} href={item.href} label={item.label} className="focus-ring flex min-h-11 items-center rounded-lg px-3 py-2.5 text-sm font-semibold text-[#514856]" activeClassName="bg-[#f3f0ff] text-[#160847]" />)}</nav><form action={signOutAction} className="border-t border-[#eadde3] pt-2"><Button type="submit" variant="secondary" className="w-full">Logout</Button></form></div>
        </details>
      </>
    );
  }

  return (
    <details className="fixed inset-x-0 bottom-0 z-30 border-t border-[#eadde3] bg-white shadow-[0_-8px_24px_rgba(32,25,37,0.08)] lg:hidden">
      <summary className="cursor-pointer list-none px-4 py-3 text-center text-sm font-semibold text-[#342b38]">{mobileMenuLabel}</summary>
      <div className="flex max-h-[calc(100dvh-3rem)] flex-col border-t border-[#eadde3]">
        <nav className="grid grid-cols-2 gap-1 overflow-y-auto p-2" aria-label={mobileMenuNavigationLabel}>
          {items.map((item) => <ActiveDashboardLink key={item.href} href={item.href} label={item.label} className="focus-ring min-h-11 rounded-lg px-3 py-2.5 text-center text-sm font-semibold text-[#514856]" activeClassName="bg-[#f3f0ff] text-[#160847]" />)}
        </nav>
        <form action={signOutAction} className="shrink-0 border-t border-[#eadde3] p-3"><Button type="submit" variant="secondary" className="w-full">Logout</Button></form>
      </div>
    </details>
  );
}
