export function RouteLoading({ label = "Loading your workspace…" }: { label?: string }) {
  return (
    <div className="mx-auto max-w-5xl animate-pulse space-y-4" aria-live="polite" aria-busy="true">
      <p className="text-sm font-medium text-[#66616f]">{label}</p>
      <div className="h-32 rounded-lg bg-[#f7e8ef]" />
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="h-28 rounded-lg bg-[#f7e8ef]" />
        <div className="h-28 rounded-lg bg-[#f7e8ef]" />
      </div>
    </div>
  );
}
