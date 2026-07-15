import type {
  InputHTMLAttributes,
  LabelHTMLAttributes,
  SelectHTMLAttributes,
} from "react";

export function Label(props: LabelHTMLAttributes<HTMLLabelElement>) {
  return <label className="text-sm font-semibold text-[#342b38]" {...props} />;
}

export function TextInput(props: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className="focus-ring min-h-12 w-full rounded-lg border border-[#dfd2d9] bg-white px-4 text-base text-[#201925] shadow-sm"
      {...props}
    />
  );
}

export function SelectField(props: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className="focus-ring min-h-12 w-full rounded-lg border border-[#dfd2d9] bg-white px-4 text-base text-[#201925] shadow-sm"
      {...props}
    />
  );
}
