import type { ReactNode } from "react";

export function PageHero({ eyebrow, title, children }: { eyebrow: string; title: string; children: ReactNode }) {
  return <section className="bg-[#fff6f9]"><div className="mx-auto max-w-6xl px-4 py-14 sm:px-6 sm:py-18 lg:px-8"><p className="text-sm font-bold uppercase tracking-[.14em] text-[#bc1f55]">{eyebrow}</p><h1 className="mt-3 max-w-3xl text-4xl font-bold tracking-tight text-[#201925] sm:text-5xl">{title}</h1><div className="mt-5 max-w-2xl text-lg leading-8 text-[#5e5662]">{children}</div></div></section>;
}

export function MarketingShell({ children }: { children: ReactNode }) {
  return <div className="mx-auto max-w-6xl px-4 py-12 sm:px-6 lg:px-8">{children}</div>;
}
