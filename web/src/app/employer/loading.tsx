function Line({ className = "" }: { className?: string }) {
  return <div className={`rounded bg-[#eadde3]/80 ${className}`} />;
}

export default function EmployerLoading() {
  return (
    <div className="grid gap-6" aria-busy="true" aria-label="Loading employer dashboard">
      <div>
        <Line className="h-7 w-52" />
        <Line className="mt-3 h-4 w-full max-w-xl" />
      </div>
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <div className="flex items-start justify-between gap-3">
          <div className="w-full max-w-sm space-y-3"><Line className="h-5 w-40" /><Line className="h-4 w-full" /></div>
          <Line className="h-7 w-24" />
        </div>
        <Line className="mt-6 h-4 w-64" />
        <Line className="mt-5 h-10 w-44" />
      </section>
      <div className="grid gap-4 md:grid-cols-4">
        {["shortlist", "pending", "accepted", "matches"].map((key) => (
          <section key={key} className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
            <Line className="h-4 w-24" /><Line className="mt-4 h-8 w-12" /><Line className="mt-5 h-4 w-10" />
          </section>
        ))}
      </div>
      <div className="grid gap-4 md:grid-cols-2">
        {["search", "messages"].map((key) => (
          <section key={key} className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
            <Line className="h-5 w-40" /><Line className="mt-3 h-4 w-full" /><Line className="mt-2 h-4 w-4/5" /><Line className="mt-5 h-10 w-36" />
          </section>
        ))}
      </div>
      <span className="sr-only">Loading dashboard details</span>
    </div>
  );
}
