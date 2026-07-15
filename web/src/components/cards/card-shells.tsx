export function CandidateCardShell({ children }: { children: React.ReactNode }) {
  return <article className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">{children}</article>;
}

export function EmployerCardShell({ children }: { children: React.ReactNode }) {
  return <article className="rounded-lg border border-[#dbe7e1] bg-white p-5 shadow-sm">{children}</article>;
}

export function JobCardShell({ children }: { children: React.ReactNode }) {
  return <article className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">{children}</article>;
}
