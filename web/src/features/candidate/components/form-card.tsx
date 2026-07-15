export function FormCard({ children }: { children: React.ReactNode }) {
  return (
    <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      {children}
    </section>
  );
}

export function FieldError({ children }: { children?: React.ReactNode }) {
  if (!children) return null;
  return <p className="text-sm font-semibold text-[#9a1744]">{children}</p>;
}
