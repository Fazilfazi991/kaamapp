import Link from "next/link";
import { StatusBadge } from "@/components/ui/status-badge";
import { Button, ButtonLink } from "@/components/ui/button";
import { statusLabel, statusTone } from "@/features/admin/validation/review";

export function AdminPageHeader({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <div className="mb-6">
      <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[#8a7c88]">Kaam admin</p>
      <h1 className="mt-2 text-2xl font-bold text-[#201925]">{title}</h1>
      <p className="mt-2 max-w-3xl text-sm leading-6 text-[#66616f]">{description}</p>
    </div>
  );
}

export function AdminStatCard({ label, value }: { label: string; value: number | string }) {
  return (
    <section className="rounded-lg border border-[#eadde3] bg-white p-4 shadow-sm">
      <p className="text-sm font-medium text-[#66616f]">{label}</p>
      <p className="mt-2 text-2xl font-bold text-[#201925]">{value}</p>
    </section>
  );
}

export function FilterBar({
  search,
  status,
  children,
}: {
  search?: string;
  status?: string;
  children?: React.ReactNode;
}) {
  return (
    <form className="mb-5 grid gap-3 rounded-lg border border-[#eadde3] bg-white p-4 shadow-sm md:grid-cols-[1fr_180px_auto]">
      <input
        name="q"
        defaultValue={search}
        placeholder="Search"
        className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 text-sm"
      />
      <select
        name="status"
        defaultValue={status ?? ""}
        className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 text-sm"
      >
        <option value="">All statuses</option>
        <option value="pending">Pending</option>
        <option value="pending_verification">Pending verification</option>
        <option value="active">Active</option>
        <option value="draft">Draft</option>
        <option value="verified">Verified</option>
        <option value="approved">Approved</option>
        <option value="rejected">Rejected</option>
        <option value="resubmission_requested">Needs resubmission</option>
        <option value="blocked">Blocked</option>
      </select>
      <Button type="submit" className="min-h-11 py-2">Filter</Button>
      {children}
    </form>
  );
}

export function AdminStatus({ status }: { status?: string | null }) {
  return <StatusBadge tone={statusTone(status)}>{statusLabel(status)}</StatusBadge>;
}

export function AdminTable({
  headers,
  rows,
  empty,
}: {
  headers: string[];
  rows: React.ReactNode[];
  empty: string;
}) {
  if (!rows.length) {
    return (
      <div className="rounded-lg border border-dashed border-[#d8c8d1] bg-white p-8 text-center text-sm text-[#66616f]">
        {empty}
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-lg border border-[#eadde3] bg-white shadow-sm">
      <table className="hidden w-full border-collapse text-left text-sm md:table">
        <thead className="bg-[#f8f1f5] text-xs uppercase tracking-[0.08em] text-[#6d6270]">
          <tr>{headers.map((header) => <th key={header} className="px-4 py-3">{header}</th>)}</tr>
        </thead>
        <tbody className="divide-y divide-[#f0e4eb]">{rows}</tbody>
      </table>
      <div className="grid gap-3 p-3 md:hidden">{rows}</div>
    </div>
  );
}

export function DetailSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mb-5 rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <h2 className="text-lg font-semibold text-[#201925]">{title}</h2>
      <div className="mt-4 grid gap-3 text-sm text-[#4f4652]">{children}</div>
    </section>
  );
}

export function Field({ label, value }: { label: string; value?: React.ReactNode }) {
  return (
    <div>
      <dt className="text-xs font-semibold uppercase tracking-[0.1em] text-[#8a7c88]">{label}</dt>
      <dd className="mt-1 break-words text-[#201925]">{value || "Not provided"}</dd>
    </div>
  );
}

export function SafeLink({ href, children }: { href: string; children: React.ReactNode }) {
  return <Link className="font-semibold text-[#bc1f55] hover:underline" href={href}>{children}</Link>;
}

export function RowAction({ href, children }: { href: string; children: React.ReactNode }) {
  return <ButtonLink href={href} variant="secondary" className="min-h-9 px-3 py-2">{children}</ButtonLink>;
}
