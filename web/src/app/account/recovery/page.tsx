import { Header } from "@/components/layout/header";
import { Footer } from "@/components/layout/footer";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { routes } from "@/config/routes";

export default function AccountRecoveryPage() {
  return (
    <>
      <Header />
      <main className="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8">
        <EmptyStateCard
          title="Your account setup is incomplete"
          description="Please choose how you want to use Kaam. A role can only be created when no role exists for this authenticated account."
          actionHref={routes.register}
          actionLabel="Choose account type"
        />
      </main>
      <Footer />
    </>
  );
}
