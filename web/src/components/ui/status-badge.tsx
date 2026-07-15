type Tone = "success" | "warning" | "neutral" | "danger";

const toneClasses: Record<Tone, string> = {
  success: "bg-[#e7f7ee] text-[#176b3b]",
  warning: "bg-[#fff4d6] text-[#7a5610]",
  neutral: "bg-[#ece7ec] text-[#514856]",
  danger: "bg-[#ffe4eb] text-[#9a1744]",
};

export function StatusBadge({
  children,
  tone = "neutral",
}: {
  children: React.ReactNode;
  tone?: Tone;
}) {
  return (
    <span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${toneClasses[tone]}`}>
      {children}
    </span>
  );
}
