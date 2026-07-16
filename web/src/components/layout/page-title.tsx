export function PageTitle({
  title,
  description,
}: {
  title: string;
  description?: string;
}) {
  return (
    <div>
      <h1 className="text-2xl font-bold tracking-tight text-[#201925] sm:text-3xl">
        {title}
      </h1>
      {description ? (
        <p className="mt-2 max-w-2xl text-sm leading-6 text-[#66616f]">
          {description}
        </p>
      ) : null}
    </div>
  );
}
