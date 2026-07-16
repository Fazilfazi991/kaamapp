import { StatusBadge } from "@/components/ui/status-badge";

export function StatCard({
  title,
  value,
  note,
  tone = "neutral",
}: {
  title: string;
  value: string;
  note: string;
  tone?: "success" | "warning" | "neutral" | "danger";
}) {
  return (
    <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <div className="flex items-start justify-between gap-3">
        <h2 className="text-sm font-semibold text-[#66616f]">{title}</h2>
        <StatusBadge tone={tone}>{value}</StatusBadge>
      </div>
      <p className="mt-4 text-sm leading-6 text-[#3b3340]">{note}</p>
    </section>
  );
}
