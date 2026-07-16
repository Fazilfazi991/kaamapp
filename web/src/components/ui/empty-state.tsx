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
    <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <h2 className="text-lg font-semibold text-[#201925]">{title}</h2>
      <p className="mt-2 text-sm leading-6 text-[#66616f]">{description}</p>
      {actionHref && actionLabel ? (
        <ButtonLink href={actionHref} className="mt-4" variant="secondary">
          {actionLabel}
        </ButtonLink>
      ) : null}
    </section>
  );
}
