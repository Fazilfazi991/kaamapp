import { LoadingIndicator } from "@/components/ui/loading-indicator";

export default function AdminLoading() {
  return (
    <div className="rounded-xl border border-[#eadde3] bg-white p-6 shadow-sm" aria-busy="true">
      <LoadingIndicator label="Loading admin workspace..." />
    </div>
  );
}
