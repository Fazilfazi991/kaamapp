import { DashboardSidebar } from "./dashboard-sidebar";
import { MobileNavigation } from "./mobile-nav";

export function DashboardShell({
  items,
  title,
  account,
  children,
}: {
  items: Array<{ href: string; label: string }>;
  title: string;
  account?: { email: string | null; role: string; name?: string | null };
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-[#fffafc] lg:flex">
      <DashboardSidebar items={items} title={title} account={account} />
      <main className="min-w-0 flex-1 px-4 py-5 pb-24 sm:px-6 lg:px-8 lg:py-8">
        <div className="mx-auto max-w-6xl">{children}</div>
      </main>
      <MobileNavigation items={items} variant={title === "Candidate" ? "candidate" : "default"} />
    </div>
  );
}
