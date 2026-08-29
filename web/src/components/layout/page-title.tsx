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
        <p className="mt-1 max-w-2xl text-sm leading-5 text-[#66616f]">
          {description}
        </p>
      ) : null}
    </div>
  );
}
