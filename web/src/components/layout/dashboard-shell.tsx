import { DashboardSidebar } from "./dashboard-sidebar";
import { MobileNavigation } from "./mobile-nav";
import { signOutAction } from "@/lib/auth/session";
import { Button } from "@/components/ui/button";

export function DashboardShell({
  items,
  title,
  account,
  children,
}: {
  items: Array<{ href: string; label: string }>;
  title: string;
  account: { email: string | null; role: string };
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-[#fffafc] lg:flex">
      <DashboardSidebar items={items} title={title} />
      <main className="min-w-0 flex-1 px-4 py-5 pb-24 sm:px-6 lg:px-8 lg:py-8">
        <div className="mx-auto mb-5 flex max-w-5xl flex-col gap-3 rounded-lg border border-[#eadde3] bg-white p-4 shadow-sm sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[#8a7c88]">
              Signed in
            </p>
            <p className="mt-1 text-sm font-semibold text-[#201925]">
              {account.email ?? "Your KAAM workspace"}
            </p>
          </div>
          <div className="flex items-center gap-3">
            <span className="rounded-full bg-[#f7f2f5] px-3 py-1 text-xs font-semibold capitalize text-[#514856]">
              {account.role}
            </span>
            <form action={signOutAction}>
              <Button type="submit" variant="secondary" className="min-h-10 px-3 py-2">
                Logout
              </Button>
            </form>
          </div>
        </div>
        <div className="mx-auto max-w-5xl">{children}</div>
      </main>
      <MobileNavigation items={items} />
    </div>
  );
}
