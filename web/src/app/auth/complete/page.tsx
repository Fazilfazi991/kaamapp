import { Suspense } from "react";
import { Header } from "@/components/layout/header";
import { LoadingIndicator } from "@/components/ui/loading-indicator";
import { GoogleOAuthComplete } from "@/features/auth/google-oauth-complete";

export default function GoogleOAuthCompletePage() {
  return (
    <>
      <Header />
      <main className="mx-auto grid min-h-[calc(100vh-82px)] max-w-xl place-items-center px-4 py-10 sm:px-6">
        <div className="w-full">
          <Suspense fallback={<LoadingIndicator label="Completing Google sign-in" />}>
            <GoogleOAuthComplete />
          </Suspense>
        </div>
      </main>
    </>
  );
}
