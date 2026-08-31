"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";

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
  leading,
  prefetch,
}: {
  href: string;
  label: string;
  className: string;
  activeClassName: string;
  leading?: ReactNode;
  prefetch?: boolean;
}) {
  const pathname = usePathname();
  const active = isActivePath(pathname, href);

  return (
    <Link
      href={href}
      prefetch={prefetch}
      aria-current={active ? "page" : undefined}
      className={`${className} ${active ? activeClassName : ""}`}
    >
      {leading}{label}
    </Link>
  );
}

