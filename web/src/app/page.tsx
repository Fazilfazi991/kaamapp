import { Footer } from "@/components/layout/footer";
import { Header } from "@/components/layout/header";
import { HowItWorks } from "@/components/marketing/how-it-works";
import { ButtonLink } from "@/components/ui/button";
import { routes } from "@/config/routes";

export default function HomePage() {
  return (
    <>
      <Header />
      <main>
        <section className="bg-[#fff6f9]">
          <div className="mx-auto flex max-w-6xl flex-col items-center gap-8 px-4 py-14 text-center sm:px-6 md:py-18 lg:px-8">
            <div className="mx-auto max-w-3xl">
              <p className="text-sm font-bold uppercase tracking-[0.16em] text-[#bc1f55]">
                Recruitment, made mutual
              </p>
              <h1 className="mt-4 max-w-3xl text-4xl font-bold tracking-tight text-[#201925] sm:text-5xl">
                Jobs shouldn&apos;t depend on luck.
              </h1>
              <p className="mt-5 max-w-2xl text-lg leading-8 text-[#5e5662]">
                KAAM connects workers and employers based on skills, requirements and mutual interest.
              </p>
              <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
                <ButtonLink href={routes.candidates}>Find jobs</ButtonLink>
                <ButtonLink href={routes.employers} variant="secondary">
                  Hire workers
                </ButtonLink>
                <ButtonLink href={routes.login} variant="secondary">
                  Login
                </ButtonLink>
              </div>
            </div>
            <div className="w-full max-w-md rounded-2xl border border-[#eadde3] bg-white p-5 text-left shadow-[0_18px_45px_rgba(77,36,54,.12)]">
              <div className="flex items-center justify-between"><div><h2 className="text-lg font-semibold text-[#201925]">Amina Noor</h2><p className="mt-1 text-sm text-[#66616f]">Hospitality supervisor · Dubai</p></div><span className="rounded-full bg-[#e6f6ee] px-3 py-1 text-xs font-bold text-[#167347]">Profile ready</span></div>
              <div className="mt-5 border-y border-[#f0e5ea] py-4"><p className="text-xs font-bold uppercase tracking-wider text-[#766b74]">Key skills</p><div className="mt-2 flex flex-wrap gap-2">{["Guest service", "Team leadership", "Food safety"].map((skill) => <span className="rounded-full bg-[#fff0f5] px-3 py-1.5 text-sm font-medium text-[#922144]" key={skill}>{skill}</span>)}</div></div>
              <div className="mt-5 rounded-xl bg-[#201925] p-4 text-white"><p className="font-semibold">Employer interest</p><p className="mt-1 text-sm text-white/70">A role matching your profile</p></div>
            </div>
          </div>
        </section>

        <HowItWorks />

        <section className="bg-[#201925]">
          <div className="mx-auto flex max-w-6xl flex-col gap-5 px-4 py-10 text-white sm:px-6 md:flex-row md:items-center md:justify-between lg:px-8">
            <div>
              <p className="text-sm font-bold uppercase tracking-[.14em] text-[#ff9dbe]">KAAM mobile app</p><h2 className="mt-2 text-2xl font-bold">Coming soon</h2>
              <p className="mt-2 text-white/75">Use KAAM on the web today. The KAAM mobile app is coming soon for an even faster experience.</p>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row">
              <ButtonLink href={routes.register}>Create your KAAM profile</ButtonLink>
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
