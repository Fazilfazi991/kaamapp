import Image from "next/image";
import Link from "next/link";
import { routes } from "@/config/routes";
import { ButtonLink } from "@/components/ui/button";

export function Header() {
  return (
    <header className="border-b border-[#eadde3] bg-white/95">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
        <Link href={routes.home} className="flex items-center gap-3">
          <Image src="/kaam-logo.webp" alt="Kaam" width={104} height={42} priority />
        </Link>
        <nav className="hidden items-center gap-2 sm:flex" aria-label="Primary">
          <ButtonLink href={routes.login} variant="ghost">
            Login
          </ButtonLink>
          <ButtonLink href={routes.candidateDashboard} variant="secondary">
            Find Work
          </ButtonLink>
          <ButtonLink href={routes.employerDashboard}>Hire Talent</ButtonLink>
        </nav>
        <ButtonLink href={routes.login} className="sm:hidden" variant="secondary">
          Login
        </ButtonLink>
      </div>
    </header>
  );
}
