"use client";

import { useActionState, useMemo, useState } from "react";
import { Label, SelectField } from "@/components/ui/form";
import { routes } from "@/config/routes";
import {
  currentResidenceCountries,
  preferredWorkCountries,
  regionsForCountry,
  normalizeCountry,
} from "@/features/candidate/constants";
import { OnboardingSubmitButton } from "@/features/candidate/components/onboarding-submit-button";
import { saveLocationDetails } from "@/features/candidate/server/actions";

export function LocationForm({
  currentCountry,
  currentRegion,
  preferredCountry,
  preferredRegion,
  next = routes.candidateOnboardingExperience,
}: {
  currentCountry?: string | null;
  currentRegion?: string | null;
  preferredCountry?: string | null;
  preferredRegion?: string | null;
  next?: string;
}) {
  const [current, setCurrent] = useState(normalizeCountry(currentCountry ?? "") || "UAE");
  const [currentArea, setCurrentArea] = useState(currentRegion ?? "");
  const [preferred, setPreferred] = useState(normalizeCountry(preferredCountry ?? "") || "UAE");
  const [preferredArea, setPreferredArea] = useState(preferredRegion ?? "");
  const [state, formAction] = useActionState(saveLocationDetails, { error: null });
  const currentRegions = useMemo(() => regionsForCountry(current), [current]);
  const preferredRegions = useMemo(() => regionsForCountry(preferred), [preferred]);

  return (
    <form action={formAction} className="grid gap-4">
      <input type="hidden" name="next" value={next} />
      <label className="grid gap-2">
        <Label>Current residence country</Label>
        <SelectField
          name="currentCountry"
          value={current}
          onChange={(event) => { setCurrent(event.target.value); setCurrentArea(""); }}
        >
          {currentResidenceCountries.map((country) => (
            <option key={country}>{country}</option>
          ))}
        </SelectField>
      </label>
      <label className="grid gap-2">
        <Label>{current === "India" ? "Current Indian state" : "Current emirate"}</Label>
        <SelectField name="currentRegion" value={currentArea} onChange={(event) => setCurrentArea(event.target.value)}>
          <option value="">Select</option>
          {currentRegions.map((region) => (
            <option key={region}>{region}</option>
          ))}
        </SelectField>
      </label>
      <label className="grid gap-2">
        <Label>Preferred work country</Label>
        <SelectField
          name="preferredCountry"
          value={preferred}
          onChange={(event) => { setPreferred(event.target.value); setPreferredArea(""); }}
        >
          {preferredWorkCountries.map((country) => (
            <option key={country}>{country}</option>
          ))}
        </SelectField>
      </label>
      {preferred === "UAE" ? <label className="grid gap-2">
        <Label>Preferred UAE emirate</Label>
        <SelectField name="preferredRegion" value={preferredArea} onChange={(event) => setPreferredArea(event.target.value)}>
          <option value="">Select</option>
          {preferredRegions.map((region) => (
            <option key={region}>{region}</option>
          ))}
        </SelectField>
      </label> : <input type="hidden" name="preferredRegion" value="" />}
      {state.error ? <p role="alert" className="rounded-lg border border-[#f1b6c8] bg-[#fff4f7] p-3 text-sm font-medium text-[#8f1741]">{state.error}</p> : null}
      <div className="sticky bottom-16 flex gap-3 bg-white/95 py-3 sm:static">
        <OnboardingSubmitButton />
      </div>
    </form>
  );
}
