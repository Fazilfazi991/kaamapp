import { Header } from "@/components/layout/header";
import { Footer } from "@/components/layout/footer";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default function AccountConflictPage() {
  return (
    <>
      <Header />
      <main className="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8">
        <EmptyStateCard
          title="Account support needed"
          description="We found conflicting account records. Please contact Kaam support before continuing so your account can be reviewed safely."
        />
      </main>
      <Footer />
    </>
  );
}
