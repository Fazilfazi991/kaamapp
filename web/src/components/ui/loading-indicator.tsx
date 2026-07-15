export function LoadingIndicator({ label = "Loading" }: { label?: string }) {
  return (
    <div className="flex items-center gap-3 text-sm text-[#66616f]" role="status">
      <span className="h-4 w-4 animate-spin rounded-full border-2 border-[#eadde3] border-t-[#e53670]" />
      {label}
    </div>
  );
}
