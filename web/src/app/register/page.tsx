import { Suspense } from "react";
import { Header } from "@/components/layout/header";
import { PageTitle } from "@/components/layout/page-title";
import { AuthForm } from "@/features/auth/auth-form";
import { AuthBrandPanel } from "@/features/auth/auth-brand-panel";
import { LoadingIndicator } from "@/components/ui/loading-indicator";
import { redirectAuthenticatedAuthPage } from "@/lib/auth/session";
import { supabaseConfigError } from "@/lib/supabase/env";
import type { AppAccountRole } from "@/lib/auth/routing";

export default async function RegisterPage({ searchParams }: { searchParams: Promise<{ role?: string }> }) {
  const configError = supabaseConfigError();
  if (!configError) await redirectAuthenticatedAuthPage();
  const requestedRole = (await searchParams).role;
  const initialRole: AppAccountRole = requestedRole === "employer" ? "employer" : "candidate";

  return (
    <>
      <Header />
      <main className="min-h-[calc(100dvh-82px)] bg-gradient-to-b from-[#fffafd] via-white to-[#fff7fa]">
        <div className="mx-auto grid w-full max-w-6xl items-center gap-6 px-4 py-6 sm:px-6 sm:py-8 lg:min-h-[calc(100dvh-82px)] lg:grid-cols-[minmax(0,.95fr)_minmax(410px,.85fr)] lg:gap-10 lg:px-8 lg:py-10">
          <AuthBrandPanel mode="register" />
          <section className="mx-auto w-full max-w-[500px]">
            <PageTitle
              title="Create your KAAM account"
              description="Choose Candidate or Employer, then verify your email with a secure one-time code."
            />
            <div className="mt-6">
              <Suspense fallback={<LoadingIndicator label="Preparing registration" />}>
                <AuthForm mode="register" initialRole={initialRole} configError={configError} />
              </Suspense>
            </div>
          </section>
        </div>
      </main>
    </>
  );
}
