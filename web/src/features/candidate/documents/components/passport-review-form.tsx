import { Button } from "@/components/ui/button";
import { savePassportReview } from "@/features/candidate/documents/server/actions";
import type { CandidateDocumentsRow } from "@/features/candidate/documents/types";

const fields: Array<{
  name: keyof CandidateDocumentsRow;
  label: string;
  type?: string;
  required?: boolean;
}> = [
  { name: "full_name", label: "Full name", required: true },
  { name: "passport_number", label: "Passport number", required: true },
  { name: "nationality", label: "Nationality", required: true },
  { name: "dob", label: "Date of birth", type: "date", required: true },
  { name: "gender", label: "Gender" },
  { name: "passport_issue_date", label: "Issue date", type: "date" },
  { name: "passport_expiry_date", label: "Expiry date", type: "date", required: true },
  { name: "place_of_birth", label: "Place of birth" },
  { name: "country_of_issue", label: "Country of issue" },
];

export function PassportReviewForm({
  row,
  ocr,
}: {
  row: CandidateDocumentsRow | null;
  ocr?: string;
}) {
  return (
    <form action={savePassportReview} className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <div>
        <h2 className="text-lg font-semibold text-[#201925]">Review passport details</h2>
        <p className="mt-2 text-sm leading-6 text-[#66616f]">
          {ocr === "success"
            ? "OCR filled the details it could read. Please confirm before submitting for review."
            : "Enter or correct the passport details before submitting for review."}
        </p>
      </div>

      <div className="mt-5 grid gap-4 md:grid-cols-2">
        {fields.map((field) => (
          <label key={field.name} className="grid gap-2 text-sm">
            <span className="font-semibold text-[#3b3340]">{field.label}</span>
            <input
              name={field.name}
              type={field.type ?? "text"}
              required={field.required}
              defaultValue={String(row?.[field.name] ?? "")}
              className="focus-ring rounded-lg border border-[#d9cfd8] bg-white px-3 py-3 text-[#201925]"
            />
          </label>
        ))}
      </div>

      <div className="mt-5 flex flex-wrap gap-3">
        <Button type="submit" name="intent" value="draft" variant="secondary">
          Save draft
        </Button>
        <Button type="submit" name="intent" value="submit">
          Submit for review
        </Button>
      </div>
    </form>
  );
}
