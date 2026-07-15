import Link from "next/link";
import type { AnchorHTMLAttributes, ButtonHTMLAttributes, ReactNode } from "react";

type Variant = "primary" | "secondary" | "ghost";

const variantClasses: Record<Variant, string> = {
  primary: "bg-[#e53670] text-white hover:bg-[#bc1f55]",
  secondary: "border border-[#e53670] bg-white text-[#bc1f55] hover:bg-[#fff0f5]",
  ghost: "text-[#3b3340] hover:bg-[#f7e8ef]",
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
