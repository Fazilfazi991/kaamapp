import { Suspense } from "react";
import { Header } from "@/components/layout/header";
import { PageTitle } from "@/components/layout/page-title";
import { AuthForm } from "@/features/auth/auth-form";
import { LoadingIndicator } from "@/components/ui/loading-indicator";

export default function RegisterPage() {
  return (
    <>
      <Header />
      <main className="mx-auto grid min-h-[calc(100vh-82px)] max-w-5xl gap-8 px-4 py-10 sm:px-6 md:grid-cols-[0.8fr_1fr] lg:px-8">
        <PageTitle
          title="Create your Kaam account"
          description="Choose candidate or employer, then verify your email with OTP. Phone OTP and passwords are intentionally not used in this foundation."
        />
        <Suspense fallback={<LoadingIndicator label="Preparing registration" />}>
          <AuthForm />
        </Suspense>
      </main>
    </>
  );
}
