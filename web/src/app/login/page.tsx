import { Suspense } from "react";
import { Header } from "@/components/layout/header";
import { PageTitle } from "@/components/layout/page-title";
import { AuthForm } from "@/features/auth/auth-form";
import { LoadingIndicator } from "@/components/ui/loading-indicator";
import { redirectAuthenticatedAuthPage } from "@/lib/auth/session";
import { supabaseConfigError } from "@/lib/supabase/env";

export default async function LoginPage() {
  const configError = supabaseConfigError();
  if (!configError) await redirectAuthenticatedAuthPage();

  return (
    <>
      <Header />
      <main className="mx-auto grid min-h-[calc(100vh-82px)] max-w-5xl gap-8 px-4 py-10 sm:px-6 md:grid-cols-[0.8fr_1fr] lg:px-8">
        <PageTitle
          title="Login to Kaam"
          description="Use email OTP to continue as a candidate or employer. Your account role is verified against Supabase after login."
        />
        <Suspense fallback={<LoadingIndicator label="Preparing login" />}>
          <AuthForm mode="login" configError={configError} />
        </Suspense>
      </main>
    </>
  );
}
