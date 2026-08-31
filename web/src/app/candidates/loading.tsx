import { LoadingIndicator } from "@/components/ui/loading-indicator";

export default function CandidateAuthLoading() {
  return (
    <main className="mx-auto max-w-xl px-4 py-12" aria-busy="true">
      <LoadingIndicator label="Loading candidate page..." />
    </main>
  );
}
