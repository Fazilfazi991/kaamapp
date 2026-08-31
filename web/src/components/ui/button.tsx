import Link from "next/link";
import type { AnchorHTMLAttributes, ButtonHTMLAttributes, ReactNode } from "react";

type Variant = "primary" | "secondary" | "ghost";

const variantClasses: Record<Variant, string> = {
  primary: "bg-[var(--kaam-purple)] text-white hover:bg-[var(--kaam-purple-hover)]",
  secondary: "border border-[var(--kaam-purple)] bg-white text-[var(--kaam-purple)] hover:bg-[#f7f4ff]",
  ghost: "text-[var(--kaam-purple)] hover:bg-[#f7f4ff]",
};

const baseClasses =
  "focus-ring inline-flex min-h-12 items-center justify-center rounded-lg px-5 py-3 text-sm font-semibold transition";

export function Button({
  variant = "primary",
  className = "",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant }) {
  return (
    <button
      className={`${baseClasses} ${variantClasses[variant]} ${className}`}
      {...props}
    />
  );
}

export function ButtonLink({
  variant = "primary",
  className = "",
  children,
  ...props
}: AnchorHTMLAttributes<HTMLAnchorElement> & {
  href: string;
  prefetch?: boolean;
  variant?: Variant;
  children: ReactNode;
}) {
  return (
    <Link
      className={`${baseClasses} ${variantClasses[variant]} ${className}`}
      {...props}
    >
      {children}
    </Link>
  );
}
