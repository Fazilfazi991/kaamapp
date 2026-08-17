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
        <section className="relative overflow-hidden bg-[radial-gradient(circle_at_82%_25%,rgba(252,189,210,.42),transparent_30%),linear-gradient(135deg,#fffafd,#fff4f8)]">
          <div className="mx-auto grid max-w-7xl gap-10 px-4 py-14 sm:px-6 lg:grid-cols-[.9fr_1.1fr] lg:items-center lg:gap-12 lg:px-8 lg:py-18">
            <div className="max-w-xl text-left">
              <p className="text-sm font-bold uppercase tracking-[0.16em] text-[#bc1f55]">
                Recruitment, made mutual
              </p>
              <h1 className="mt-4 max-w-xl text-5xl font-extrabold tracking-[-.045em] text-[#201925] sm:text-6xl lg:text-7xl lg:leading-[.98]">
                Jobs shouldn&apos;t<br />depend on <span className="relative inline-block">luck.<span className="absolute -bottom-2 left-0 h-1.5 w-full -rotate-2 rounded-full bg-[#e53670]" /></span>
              </h1>
              <p className="mt-8 max-w-xl text-lg leading-8 text-[#5e5662]">
                KAAM connects workers and employers based on skills, requirements and mutual interest.
              </p>
              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <ButtonLink href={routes.candidates}>Find jobs</ButtonLink>
                <ButtonLink href={routes.employers} variant="secondary">
                  Hire workers
                </ButtonLink>
                <ButtonLink href={routes.login} variant="secondary">
                  Login
                </ButtonLink>
              </div>
              <div className="mt-8 grid gap-4 border-t border-[#f1dce5] pt-6 sm:grid-cols-3">
                {[['◈','Verified Employers','Trusted opportunities'],['◉','Skill-Based Matching','Better matches, better jobs'],['▣','Secure & Private','Your data is protected']].map(([icon,title,text]) => <div className="flex items-start gap-2" key={title}><span className="text-xl text-[#e53670]">{icon}</span><div><p className="text-sm font-bold text-[#342b38]">{title}</p><p className="mt-0.5 text-xs text-[#766b74]">{text}</p></div></div>)}
              </div>
            </div>
            <div className="relative mx-auto w-full max-w-2xl py-3 lg:min-h-[550px]">
              <div className="absolute inset-8 rounded-full border border-[#f49abe]" />
              <div className="relative z-10 w-[78%] rounded-3xl border border-[#f2e4eb] bg-white p-6 shadow-[0_22px_48px_rgba(92,43,64,.16)] sm:p-7">
                <div className="flex items-center gap-4"><div className="grid h-16 w-16 place-items-center rounded-full bg-gradient-to-br from-[#f7c7d7] to-[#b86d87] text-xl font-bold text-white">AN</div><div><h2 className="text-xl font-bold text-[#201925]">Amina Noor</h2><p className="mt-1 text-sm text-[#706578]">Hospitality supervisor · Dubai</p></div><span className="ml-auto rounded-full bg-[#e6f6ee] px-3 py-1 text-xs font-bold text-[#167347]">Profile ready</span></div>
                <div className="mt-6 border-y border-[#f0e5ea] py-4"><p className="text-xs font-bold uppercase tracking-wider text-[#766b74]">Key skills</p><div className="mt-3 flex flex-wrap gap-2">{["Guest service", "Team leadership", "Food safety"].map((skill) => <span className="rounded-full bg-[#fff0f5] px-3 py-1.5 text-sm font-medium text-[#922144]" key={skill}>{skill}</span>)}</div></div>
                <div className="mt-5 flex items-center justify-between gap-4 rounded-2xl bg-[#201925] p-5 text-white"><div><p className="font-semibold">Open to roles like</p><p className="mt-2 text-sm leading-6 text-white/80">Hospitality Supervisor, Shift Leader, Guest Service Manager</p></div><span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-[#f6a4c3] text-xl text-[#bc1f55]">↗</span></div>
              </div>
              <div className="absolute right-0 top-28 z-20 w-[48%] rounded-3xl border border-[#f2e4eb] bg-white p-5 shadow-[0_18px_40px_rgba(92,43,64,.16)]"><p className="font-bold text-[#e53670]">▦ &nbsp; Employer interest</p><p className="mt-5 font-semibold text-[#342b38]">Hospitality Group Dubai ✓</p><p className="mt-6 text-sm text-[#706578]">Role match</p><p className="text-3xl font-extrabold text-[#e53670]">92% <span className="text-base">★★★★★</span></p><div className="mt-5 rounded-2xl bg-[#fff0f6] p-3 text-sm"><p className="font-bold text-[#342b38]">♥ They&apos;re interested in your profile!</p><p className="mt-1 text-xs text-[#706578]">You match on skills, location and experience.</p></div></div>
              <div className="absolute bottom-0 left-0 z-10 flex w-[84%] divide-x divide-[#f0e5ea] rounded-2xl bg-white p-4 shadow-[0_12px_30px_rgba(92,43,64,.1)]">{[['Job seekers','Active profiles'],['Employers','Verified companies'],['Matches','Mutual connections']].map(([label,text])=><div key={label} className="flex-1 px-3"><p className="font-bold text-[#342b38]">{label}</p><p className="mt-1 text-xs text-[#766b74]">{text}</p></div>)}</div>
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
