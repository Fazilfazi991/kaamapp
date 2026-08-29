import { Suspense } from "react";
import { Header } from "@/components/layout/header";
import { PageTitle } from "@/components/layout/page-title";
import { LoadingIndicator } from "@/components/ui/loading-indicator";
import { AuthBrandPanel } from "@/features/auth/auth-brand-panel";
import { AuthForm } from "@/features/auth/auth-form";
import { redirectAuthenticatedAuthPage } from "@/lib/auth/session";
import { supabaseConfigError } from "@/lib/supabase/env";
import type { AppAccountRole, AuthMode } from "@/lib/auth/routing";

const journeyCopy = {
  candidate: {
    login: {
      title: "Candidate login",
      description: "Sign in to continue your profile, review employer interest, and manage your matches.",
    },
    register: {
      title: "Register as a Candidate",
      description: "Create your job-seeker profile and help the right employers discover your skills.",
    },
  },
  employer: {
    login: {
      title: "Employer login",
      description: "Sign in to manage your company, find candidates, and continue active matches.",
    },
    register: {
      title: "Register as an Employer",
      description: "Create your employer account, set up your company, and start finding suitable candidates.",
    },
  },
} as const;

export async function AuthJourneyPage({ role, mode }: { role: AppAccountRole; mode: AuthMode }) {
  const configError = supabaseConfigError();
  if (!configError) await redirectAuthenticatedAuthPage({ allowMissingProfile: true });
  const copy = journeyCopy[role][mode];

  return (
    <>
      <Header />
      <main className="min-h-[calc(100dvh-82px)] bg-gradient-to-b from-[#fffafd] via-white to-[#fff7fa]">
        <div className="mx-auto grid w-full max-w-6xl items-center gap-6 px-4 py-7 sm:px-6 sm:py-10 lg:min-h-[calc(100dvh-82px)] lg:grid-cols-[minmax(0,.95fr)_minmax(410px,.85fr)] lg:gap-10 lg:px-8">
          <AuthBrandPanel mode={mode} role={role} />
          <section className="mx-auto w-full max-w-[500px]">
            <PageTitle title={copy.title} description={copy.description} />
            <div className="mt-6">
              <Suspense fallback={<LoadingIndicator label={`Preparing ${role} ${mode}`} />}>
                <AuthForm mode={mode} role={role} configError={configError} />
              </Suspense>
            </div>
          </section>
        </div>
      </main>
    </>
  );
}
