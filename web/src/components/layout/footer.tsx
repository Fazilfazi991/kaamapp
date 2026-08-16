import Link from "next/link";
import { routes } from "@/config/routes";

export function Footer() {
  return (
    <footer className="border-t border-[#eadde3] bg-[#201925] text-white">
      <div className="mx-auto grid max-w-6xl gap-6 px-4 py-10 text-sm text-white/78 sm:px-6 md:grid-cols-[1.4fr_1fr_1fr] lg:px-8">
        <p>Kaam helps workers and employers connect through verified profiles and controlled contact sharing.</p>
        <div className="grid gap-2"><Link href={routes.about}>About KAAM</Link><Link href={routes.contact}>Contact</Link><Link href={routes.howItWorks}>How KAAM works</Link></div>
        <div className="grid gap-2"><Link href={routes.privacy}>Privacy policy</Link><Link href={routes.terms}>Terms & conditions</Link><Link href={routes.accountDeletion}>Account deletion</Link></div>
      </div>
    </footer>
  );
}
