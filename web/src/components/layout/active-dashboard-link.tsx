"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

function isActivePath(pathname: string, href: string) {
  if (pathname === href) return true;
  if (href === "/admin" || href === "/candidate" || href === "/employer") return false;
  return pathname.startsWith(`${href}/`);
}

export function ActiveDashboardLink({
  href,
  label,
  className,
  activeClassName,
}: {
  href: string;
  label: string;
  className: string;
  activeClassName: string;
}) {
  const pathname = usePathname();
  const active = isActivePath(pathname, href);

  return (
    <Link
      href={href}
      aria-current={active ? "page" : undefined}
      className={`${className} ${active ? activeClassName : ""}`}
    >
      {label}
    </Link>
  );
}

