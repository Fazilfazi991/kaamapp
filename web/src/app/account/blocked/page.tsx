import { Header } from "@/components/layout/header";
import { Footer } from "@/components/layout/footer";
import { EmptyStateCard } from "@/components/ui/empty-state";
import { blockedAccountMessage } from "@/lib/auth/routing";

export default function AccountBlockedPage() {
  return (
    <>
      <Header />
      <main className="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8">
        <EmptyStateCard
          title="Account blocked"
          description={blockedAccountMessage}
        />
      </main>
      <Footer />
    </>
  );
}
