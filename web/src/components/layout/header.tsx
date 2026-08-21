import Image from "next/image";
import Link from "next/link";
import { routes } from "@/config/routes";
import { ButtonLink } from "@/components/ui/button";
import { getPublicAccountNavigation, signOutToHomeAction } from "@/lib/auth/session";

export async function Header() {
  const account = await getPublicAccountNavigation();
  const dashboardLabel = account.role === "admin" ? "Admin Dashboard" : "Go to Dashboard";
  const initials = account.displayName?.split(/\s+|@/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "K";
  const firstName = account.displayName?.trim().split(/\s+/)[0] || "Account";
  const roleLabel = account.role ? `${account.role[0].toUpperCase()}${account.role.slice(1)} account` : "KAAM account";

  return (
    <header className="border-b border-[#160847] bg-[#160847] text-white">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
        <Link href={routes.home} className="flex items-center justify-start">
          <Image src="/kaam-logo.webp" alt="KAAM Perfect Match" width={118} height={52} priority className="h-auto w-[118px]" />
        </Link>
        <nav className="ml-auto hidden items-center gap-1 md:flex" aria-label="Primary">
          <Link href={routes.home} className="focus-ring rounded-md px-3 py-2 text-sm font-medium text-white/90 hover:text-[#f56ba1]">Home</Link>
          <Link href={routes.candidates} className="focus-ring rounded-md px-3 py-2 text-sm font-medium text-white/90 hover:text-[#f56ba1]">For Candidates</Link>
          <Link href={routes.employers} className="focus-ring rounded-md px-3 py-2 text-sm font-medium text-white/90 hover:text-[#f56ba1]">For Employers</Link>
          <Link href={routes.howItWorks} className="focus-ring rounded-md px-3 py-2 text-sm font-medium text-white/90 hover:text-[#f56ba1]">How it works</Link>
        </nav>
        <div className="hidden items-center gap-2 border-l border-white/25 pl-4 md:flex">
          {account.authenticated && account.dashboardHref ? <><Link href={account.dashboardHref} className="focus-ring flex items-center gap-2 rounded-lg px-2 py-1.5 hover:bg-white/10"><span aria-hidden="true" className="grid h-9 w-9 place-items-center rounded-full border border-white/40 bg-white/10 text-xs font-bold text-white">{initials}</span><span className="flex flex-col leading-tight"><span className="text-sm font-semibold text-white">{firstName}</span><span className="text-[11px] text-white/70">{roleLabel}</span></span></Link><ButtonLink href={account.dashboardHref} className="min-h-10 bg-[#f56ba1] px-4 py-2 text-[#160847] hover:bg-[#f889b6]">Dashboard</ButtonLink><form action={signOutToHomeAction}><button type="submit" className="focus-ring rounded-md px-2 py-2 text-sm font-medium text-white/80 hover:text-[#f56ba1]">Logout</button></form></> : <><ButtonLink href={routes.login} className="min-h-10 border border-white/60 bg-transparent px-4 py-2 text-white hover:bg-white/10">Login</ButtonLink><ButtonLink href={routes.register} className="min-h-10 bg-[#f56ba1] px-4 py-2 text-[#160847] hover:bg-[#f889b6]">Get started</ButtonLink></>}
        </div>
        <details className="relative md:hidden">
          <summary className="focus-ring cursor-pointer list-none rounded-lg border border-white/60 px-4 py-3 text-sm font-semibold text-white">Menu</summary>
          <nav className="absolute right-0 top-[calc(100%+8px)] z-20 grid w-64 gap-1 rounded-xl border border-[#eadde3] bg-white p-3 shadow-lg" aria-label="Mobile primary">
            <Link href={routes.home} className="rounded-lg px-3 py-3 text-sm font-medium hover:bg-[#f7f4ff]">Home</Link>
            <Link href={routes.candidates} className="rounded-lg px-3 py-3 text-sm font-medium hover:bg-[#f7f4ff]">For Candidates</Link>
            <Link href={routes.employers} className="rounded-lg px-3 py-3 text-sm font-medium hover:bg-[#f7f4ff]">For Employers</Link>
            <Link href={routes.howItWorks} className="rounded-lg px-3 py-3 text-sm font-medium hover:bg-[#f7f4ff]">How it works</Link>
            {account.authenticated && account.dashboardHref ? <><div className="border-t border-[#eee9ff] px-3 pb-2 pt-3"><p className="font-semibold text-[#160847]">{account.displayName ?? "KAAM account"}</p><p className="mt-0.5 text-xs text-[#746975]">{roleLabel}</p></div><ButtonLink href={account.dashboardHref} className="justify-start">{dashboardLabel}</ButtonLink><form action={signOutToHomeAction} className="px-3 pt-2"><button type="submit" className="focus-ring text-sm font-semibold text-[#160847]">Logout</button></form></> : <><ButtonLink href={routes.login} variant="secondary" className="justify-start">Login</ButtonLink><ButtonLink href={routes.register}>Get started</ButtonLink></>}
          </nav>
        </details>
      </div>
    </header>
  );
}
