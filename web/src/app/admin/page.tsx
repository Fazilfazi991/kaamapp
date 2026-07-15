import { Header } from "@/components/layout/header";
import { Footer } from "@/components/layout/footer";
import { EmptyStateCard } from "@/components/ui/empty-state";

export default function AdminPage() {
  return (
    <>
      <Header />
      <main className="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8">
        <EmptyStateCard
          title="Admin application managed separately"
          description="This branch creates the public, candidate, and employer web foundation only. The admin system is intentionally not built here."
        />
      </main>
      <Footer />
    </>
  );
}
