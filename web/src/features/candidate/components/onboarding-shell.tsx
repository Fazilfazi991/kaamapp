import Link from "next/link";
import { routes } from "@/config/routes";

const steps = [
  { href: routes.candidateOnboardingPersonal, label: "Personal" },
  { href: routes.candidateOnboardingSkills, label: "Skills" },
  { href: routes.candidateOnboardingLocation, label: "Location" },
  { href: routes.candidateOnboardingExperience, label: "Experience" },
  { href: routes.candidateOnboardingReview, label: "Review" },
];

export function OnboardingShell({
  current,
  title,
  description,
  children,
}: {
  current: string;
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <div className="grid gap-6">
      <div>
        <p className="text-sm font-bold uppercase tracking-[0.16em] text-[#bc1f55]">
          Candidate onboarding
        </p>
        <h1 className="mt-2 text-2xl font-bold text-[#201925]">{title}</h1>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-[#66616f]">
          {description}
        </p>
      </div>
      <nav className="flex gap-2 overflow-x-auto pb-1" aria-label="Onboarding steps">
        {steps.map((step, index) => (
          <Link
            key={step.href}
            href={step.href}
            className={`focus-ring whitespace-nowrap rounded-full px-3 py-2 text-xs font-semibold ${
              step.href === current
                ? "bg-[#e53670] text-white"
                : "bg-white text-[#514856]"
            }`}
          >
            {index + 1}. {step.label}
          </Link>
        ))}
      </nav>
      {children}
    </div>
  );
}
