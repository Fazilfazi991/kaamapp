"use client";

import { useState } from "react";
import { PendingSubmitButton } from "@/components/ui/pending-submit-button";
import { SelectField, TextInput } from "@/components/ui/form";
import { uaeEmirates } from "@/features/candidate/constants";
import { saveCompanyLocation } from "@/features/employer/server/profile-actions";
import type { EmployerCompany } from "@/features/employer/types";
import {
  employerCompanyCountries,
  normalizeEmployerCompanyCountry,
  type EmployerCompanyCountry,
} from "./validation";

const countryLabels: Record<EmployerCompanyCountry, string> = {
  UAE: "United Arab Emirates",
  "Saudi Arabia": "Saudi Arabia",
  Qatar: "Qatar",
  Oman: "Oman",
  Bahrain: "Bahrain",
  Kuwait: "Kuwait",
};

export function CompanyLocationForm({ company, next = "/employer/onboarding/contact" }: { company: EmployerCompany | null; next?: string }) {
  const initialCountry = normalizeEmployerCompanyCountry(company?.country ?? "") || "UAE";
  const initialRegion = initialCountry === "UAE" && uaeEmirates.includes(company?.city ?? "") ? company?.city ?? "" : "";
  const [country, setCountry] = useState<EmployerCompanyCountry>(initialCountry);
  const [region, setRegion] = useState(initialRegion);

  return (
    <form action={saveCompanyLocation} className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <input type="hidden" name="next" value={next} />
      <h2 className="text-lg font-semibold text-[#201925]">Company location</h2>
      <div className="mt-5 grid gap-4 md:grid-cols-2">
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
          Country
          <SelectField
            name="country"
            value={country}
            onChange={(event) => {
              setCountry(event.target.value as EmployerCompanyCountry);
              setRegion("");
            }}
          >
            {employerCompanyCountries.map((item) => <option key={item} value={item}>{countryLabels[item]}</option>)}
          </SelectField>
        </label>
        {country === "UAE" ? (
          <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
            Emirate
            <SelectField name="region" value={region} onChange={(event) => setRegion(event.target.value)} required>
              <option value="">Select emirate</option>
              {uaeEmirates.map((item) => <option key={item}>{item}</option>)}
            </SelectField>
          </label>
        ) : <input type="hidden" name="region" value="" />}
        <label className="grid gap-2 text-sm font-semibold text-[#342b38] md:col-span-2">
          Office area / branch
          <TextInput name="officeArea" defaultValue={company?.office_area ?? ""} />
        </label>
      </div>
      <div className="mt-5"><PendingSubmitButton pendingLabel="Saving...">Save and continue</PendingSubmitButton></div>
    </form>
  );
}
