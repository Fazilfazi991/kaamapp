import { LoadingIndicator } from "@/components/ui/loading-indicator";

export default function CandidateLoading() {
  return (
    <div className="grid min-h-[45vh] place-items-center" role="status" aria-live="polite">
      <LoadingIndicator label="Loading your candidate profile..." />
    </div>
  );
}
