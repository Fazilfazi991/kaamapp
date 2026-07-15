import Link from "next/link";

export function MobileNavigation({
  items,
}: {
  items: Array<{ href: string; label: string }>;
}) {
  return (
    <nav className="sticky bottom-0 z-20 grid grid-cols-3 gap-1 border-t border-[#eadde3] bg-white p-2 sm:hidden" aria-label="Dashboard">
      {items.slice(0, 6).map((item) => (
        <Link
          key={item.href}
          href={item.href}
          className="focus-ring rounded-lg px-2 py-2 text-center text-xs font-semibold text-[#514856]"
        >
          {item.label}
        </Link>
      ))}
    </nav>
  );
}
