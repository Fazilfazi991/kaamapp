import Image from "next/image";
import Link from "next/link";
import { routes } from "@/config/routes";
import { ButtonLink } from "@/components/ui/button";
import { getPublicAccountNavigation } from "@/lib/auth/session";
import { LogoutButton } from "@/features/auth/logout-button";

export async function Header() {
  const account = await getPublicAccountNavigation();
  const initials = account.displayName?.split(/\s+|@/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "K";
  const firstName = account.displayName?.trim().split(/\s+/)[0] || "Account";
  const roleLabel = account.role ? `${account.role[0].toUpperCase()}${account.role.slice(1)} account` : "KAAM account";
  const accountLinks = account.role === "candidate"
    ? [
        { href: routes.candidateDashboard, label: "Candidate Dashboard" },
        { href: routes.candidateProfile, label: "Profile" },
        { href: routes.candidateMembership, label: "Membership" },
      ]
    : account.role === "employer"
      ? [
          { href: routes.employerDashboard, label: "Employer Dashboard" },
          { href: routes.employerSearch, label: "Find Candidates" },
          { href: routes.employerMatches, label: "Matches" },
        ]
      : account.role === "admin"
        ? [{ href: routes.admin, label: "Admin Dashboard" }]
        : account.dashboardHref
          ? [{ href: account.dashboardHref, label: "Complete account setup" }]
          : [];

  return (
    <header className="border-b border-[#160847] bg-[#160847] text-white">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
        <Link href={routes.home} className="flex items-center justify-start">
          <Image src="/kaam-logo.webp" alt="KAAM Perfect Match" width={118} height={52} priority style={{ width: 118, height: "auto" }} />
        </Link>
        <nav className="ml-auto hidden items-center gap-1 md:flex" aria-label="Primary">
          {(account.authenticated ? accountLinks : [
            { href: routes.candidates, label: "Find a Job" },
            { href: routes.employers, label: "Hire Candidates" },
            { href: routes.candidateLogin, label: "Candidate Login" },
            { href: routes.employerLogin, label: "Employer Login" },
          ]).map((item) => <Link key={item.href} href={item.href} className="focus-ring rounded-md px-3 py-2 text-sm font-medium text-white/90 hover:text-[#f56ba1]">{item.label}</Link>)}
        </nav>
        <div className="hidden items-center gap-2 border-l border-white/25 pl-4 md:flex">
          {account.authenticated && account.dashboardHref ? <><Link href={account.dashboardHref} className="focus-ring flex items-center gap-2 rounded-lg px-2 py-1.5 hover:bg-white/10"><span aria-hidden="true" className="grid h-9 w-9 place-items-center rounded-full border border-white/40 bg-white/10 text-xs font-bold text-white">{initials}</span><span className="flex flex-col leading-tight"><span className="text-sm font-semibold text-white">{firstName}</span><span className="text-[11px] text-white/70">{roleLabel}</span></span></Link><LogoutButton destination={routes.home} variant="ghost" buttonClassName="min-h-0 px-2 py-2 text-white/80 hover:bg-transparent hover:text-[#f56ba1]" /></> : null}
        </div>
        <details className="relative md:hidden">
          <summary className="focus-ring cursor-pointer list-none rounded-lg border border-white/60 px-4 py-3 text-sm font-semibold text-white">Menu</summary>
          <div className="absolute right-0 top-[calc(100%+8px)] z-20 w-[min(20rem,calc(100vw-2rem))] rounded-xl border border-[#eadde3] bg-white p-3 text-[#201925] shadow-lg">
            {account.authenticated && account.dashboardHref ? (
              <div className="grid gap-3">
                <div className="border-b border-[#eee9ff] px-3 pb-3 pt-2">
                  <p className="font-semibold text-[#160847]">{account.displayName ?? "KAAM account"}</p>
                  <p className="mt-0.5 text-xs text-[#746975]">{roleLabel}</p>
                </div>
                <nav className="grid gap-1" aria-label="Account navigation">
                  {accountLinks.map((item) => <Link key={item.href} href={item.href} className="rounded-lg px-3 py-3 text-sm font-semibold text-[#201925] hover:bg-[#f7f4ff]">{item.label}</Link>)}
                </nav>
                <LogoutButton destination={routes.home} variant="ghost" className="px-3" buttonClassName="min-h-0 justify-start px-0 py-0" />
              </div>
            ) : (
              <nav className="grid gap-1" aria-label="Mobile primary">
                <Link href={routes.home} className="rounded-lg px-3 py-3 text-sm font-medium text-[#201925] hover:bg-[#f7f4ff]">Home</Link>
                <Link href={routes.candidates} className="rounded-lg px-3 py-3 text-sm font-medium text-[#201925] hover:bg-[#f7f4ff]">Find a Job</Link>
                <Link href={routes.employers} className="rounded-lg px-3 py-3 text-sm font-medium text-[#201925] hover:bg-[#f7f4ff]">Hire Candidates</Link>
                <ButtonLink href={routes.candidateLogin} variant="secondary" className="mt-2 justify-start">Candidate Login</ButtonLink>
                <ButtonLink href={routes.employerLogin}>Employer Login</ButtonLink>
              </nav>
            )}
          </div>
        </details>
      </div>
    </header>
  );
}
