import { ButtonLink } from "./button";

export function EmptyStateCard({
  title,
  description,
  actionHref,
  actionLabel,
}: {
  title: string;
  description: string;
  actionHref?: string;
  actionLabel?: string;
}) {
  return (
    <section className="rounded-2xl border border-[#e7e1f2] bg-white p-4 shadow-[0_6px_16px_rgba(22,8,71,.05)]">
      <h2 className="text-base font-bold text-[#160847]">{title}</h2>
      <p className="mt-1 text-sm leading-5 text-[#66616f]">{description}</p>
      {actionHref && actionLabel ? (
        <ButtonLink href={actionHref} className="mt-3 min-h-10 px-4 py-2" variant="secondary">
          {actionLabel}
        </ButtonLink>
      ) : null}
    </section>
  );
}
