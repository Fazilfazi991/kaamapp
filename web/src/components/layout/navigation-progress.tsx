"use client";

import Link, { type LinkProps } from "next/link";
import { usePathname } from "next/navigation";
import {
  createContext,
  useContext,
  useState,
  type AnchorHTMLAttributes,
  type ReactNode,
} from "react";

type NavigationProgressState = {
  navigating: boolean;
  pendingHref: string;
  startNavigation: (href: string) => void;
};

const NavigationProgressContext = createContext<NavigationProgressState>({
  navigating: false,
  pendingHref: "",
  startNavigation: () => undefined,
});

export function NavigationProgressProvider({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const [pendingHref, setPendingHref] = useState("");
  const navigating = pendingHref.length > 0 && pendingHref !== pathname;

  return (
    <NavigationProgressContext.Provider
      value={{
        navigating,
        pendingHref,
        startNavigation: (href) => {
          setPendingHref(href);
        },
      }}
    >
      <div
        aria-hidden={!navigating}
        className={`pointer-events-none fixed inset-x-0 top-0 z-50 h-1 bg-[#e53670] shadow-[0_1px_8px_rgba(229,54,112,0.65)] transition-opacity duration-150 ${
          navigating ? "animate-pulse opacity-100" : "opacity-0"
        }`}
      />
      {children}
    </NavigationProgressContext.Provider>
  );
}

export function useNavigationProgress() {
  return useContext(NavigationProgressContext);
}

export function NavigationLink({
  href,
  onClick,
  children,
  showSpinner = false,
  ...props
}: LinkProps &
  AnchorHTMLAttributes<HTMLAnchorElement> & { children: ReactNode; showSpinner?: boolean }) {
  const { navigating, pendingHref, startNavigation } = useNavigationProgress();
  const pathname = usePathname();

  return (
    <Link
      href={href}
      onClick={(event) => {
        onClick?.(event);
        if (
          event.defaultPrevented ||
          event.button !== 0 ||
          event.metaKey ||
          event.ctrlKey ||
          event.shiftKey ||
          event.altKey ||
          navigating ||
          String(href) === pathname
        ) {
          return;
        }
        startNavigation(String(href));
      }}
      aria-busy={navigating || undefined}
      {...props}
    >
      <span>{children}</span>
      {showSpinner && navigating && pendingHref === String(href) ? (
        <span className="ml-2 size-3 animate-spin rounded-full border-2 border-current border-r-transparent" aria-label="Loading" />
      ) : null}
    </Link>
  );
}
