import { DashboardSidebar } from "./dashboard-sidebar";
import { MobileNavigation } from "./mobile-nav";

export function DashboardShell({
  items,
  title,
  children,
}: {
  items: Array<{ href: string; label: string }>;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-[#fffafc] lg:flex">
      <DashboardSidebar items={items} title={title} />
      <main className="min-w-0 flex-1 px-4 py-5 pb-24 sm:px-6 lg:px-8 lg:py-8">
        <div className="mx-auto max-w-5xl">{children}</div>
      </main>
      <MobileNavigation items={items} />
    </div>
  );
}
