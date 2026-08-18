import Image from "next/image";
import Link from "next/link";
import { routes } from "@/config/routes";
import { ButtonLink } from "@/components/ui/button";

export function Header() {
  return (
    <header className="border-b border-[#160847] bg-[#160847] text-white">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
        <Link href={routes.home} className="flex items-center justify-start">
          <Image src="/kaam-logo.webp" alt="KAAM Perfect Match" width={118} height={52} priority className="h-auto w-[118px]" />
        </Link>
        <nav className="hidden items-center gap-1 md:flex" aria-label="Primary">
          <Link href={routes.home} className="focus-ring rounded-md px-3 py-2 text-sm font-medium text-white/90 hover:text-[#f56ba1]">Home</Link>
          <Link href={routes.candidates} className="focus-ring rounded-md px-3 py-2 text-sm font-medium text-white/90 hover:text-[#f56ba1]">For Candidates</Link>
          <Link href={routes.employers} className="focus-ring rounded-md px-3 py-2 text-sm font-medium text-white/90 hover:text-[#f56ba1]">For Employers</Link>
          <Link href={routes.howItWorks} className="focus-ring rounded-md px-3 py-2 text-sm font-medium text-white/90 hover:text-[#f56ba1]">How it works</Link>
          <ButtonLink href={routes.login} className="min-h-10 border border-white/60 bg-transparent px-4 py-2 text-white hover:bg-white/10">
            Login
          </ButtonLink>
          <ButtonLink href={routes.register} className="min-h-10 bg-[#f56ba1] px-4 py-2 text-[#160847] hover:bg-[#f889b6]">Get started</ButtonLink>
        </nav>
        <details className="relative md:hidden">
          <summary className="focus-ring cursor-pointer list-none rounded-lg border border-white/60 px-4 py-3 text-sm font-semibold text-white">Menu</summary>
          <nav className="absolute right-0 top-[calc(100%+8px)] z-20 grid w-64 gap-1 rounded-xl border border-[#eadde3] bg-white p-3 shadow-lg" aria-label="Mobile primary">
            <Link href={routes.home} className="rounded-lg px-3 py-3 text-sm font-medium hover:bg-[#fff0f5]">Home</Link>
            <Link href={routes.candidates} className="rounded-lg px-3 py-3 text-sm font-medium hover:bg-[#fff0f5]">For Candidates</Link>
            <Link href={routes.employers} className="rounded-lg px-3 py-3 text-sm font-medium hover:bg-[#fff0f5]">For Employers</Link>
            <Link href={routes.howItWorks} className="rounded-lg px-3 py-3 text-sm font-medium hover:bg-[#fff0f5]">How it works</Link>
            <ButtonLink href={routes.login} variant="secondary" className="justify-start">Login</ButtonLink>
            <ButtonLink href={routes.register}>Get started</ButtonLink>
          </nav>
        </details>
      </div>
    </header>
  );
}
