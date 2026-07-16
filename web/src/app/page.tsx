import { Footer } from "@/components/layout/footer";
import { Header } from "@/components/layout/header";
import { ButtonLink } from "@/components/ui/button";
import { routes } from "@/config/routes";

const categories = [
  "Construction",
  "Cleaning",
  "Hospitality",
  "Driving and Delivery",
  "Maintenance",
  "Security",
  "Retail",
  "Domestic Work",
];

export default function HomePage() {
  return (
    <>
      <Header />
      <main>
        <section className="bg-[#fffafc]">
          <div className="mx-auto grid max-w-6xl gap-8 px-4 py-12 sm:px-6 md:grid-cols-[1.1fr_0.9fr] md:py-16 lg:px-8">
            <div>
              <p className="text-sm font-bold uppercase tracking-[0.16em] text-[#bc1f55]">
                UAE and India hiring
              </p>
              <h1 className="mt-4 max-w-3xl text-4xl font-bold tracking-tight text-[#201925] sm:text-5xl">
                Find work faster. Hire trusted workers with confidence.
              </h1>
              <p className="mt-5 max-w-2xl text-lg leading-8 text-[#5e5662]">
                Kaam connects verified candidates and employers through simple profiles,
                controlled contact sharing, and practical matching for real jobs.
              </p>
              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <ButtonLink href={routes.candidateDashboard}>Find Work</ButtonLink>
                <ButtonLink href={routes.employerDashboard} variant="secondary">
                  Hire Talent
                </ButtonLink>
                <ButtonLink href={routes.login} variant="ghost">
                  Login
                </ButtonLink>
              </div>
            </div>
            <div className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
              <h2 className="text-lg font-semibold text-[#201925]">Main worker categories</h2>
              <div className="mt-4 grid grid-cols-2 gap-3">
                {categories.map((category) => (
                  <div key={category} className="rounded-lg bg-[#f7f2f5] p-4 text-sm font-semibold text-[#342b38]">
                    {category}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section className="bg-white">
          <div className="mx-auto grid max-w-6xl gap-8 px-4 py-12 sm:px-6 md:grid-cols-2 lg:px-8">
            <Journey
              title="How candidates use Kaam"
              steps={["Create profile", "Select skills", "Complete verification", "Get matched with employers"]}
            />
            <Journey
              title="How employers use Kaam"
              steps={["Create company profile", "Search workers", "Send interest", "Connect after matching"]}
            />
          </div>
        </section>

        <section className="bg-[#f7f2f5]">
          <div className="mx-auto grid max-w-6xl gap-5 px-4 py-12 sm:px-6 md:grid-cols-4 lg:px-8">
            {[
              ["Profile verification", "Candidates build trusted work profiles before visibility."],
              ["Document review", "Identity and support documents remain controlled."],
              ["Contact sharing", "Private contact details are released only through matching rules."],
              ["Regional support", "The product is shaped for UAE and India hiring needs."],
            ].map(([title, text]) => (
              <article key={title} className="rounded-lg bg-white p-5 shadow-sm">
                <h2 className="font-semibold text-[#201925]">{title}</h2>
                <p className="mt-2 text-sm leading-6 text-[#66616f]">{text}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="bg-[#201925]">
          <div className="mx-auto flex max-w-6xl flex-col gap-5 px-4 py-10 text-white sm:px-6 md:flex-row md:items-center md:justify-between lg:px-8">
            <div>
              <h2 className="text-2xl font-bold">Ready to start with Kaam?</h2>
              <p className="mt-2 text-white/75">Choose the path that matches your account.</p>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row">
              <ButtonLink href={routes.candidateDashboard}>Find Work</ButtonLink>
              <ButtonLink href={routes.employerDashboard} variant="secondary">
                Hire Talent
              </ButtonLink>
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}

function Journey({ title, steps }: { title: string; steps: string[] }) {
  return (
    <article>
      <h2 className="text-2xl font-bold text-[#201925]">{title}</h2>
      <ol className="mt-5 grid gap-3">
        {steps.map((step, index) => (
          <li key={step} className="flex items-center gap-3 rounded-lg border border-[#eadde3] p-4">
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#e53670] text-sm font-bold text-white">
              {index + 1}
            </span>
            <span className="font-semibold text-[#342b38]">{step}</span>
          </li>
        ))}
      </ol>
    </article>
  );
}
