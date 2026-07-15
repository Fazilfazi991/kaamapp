"use client";

import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Label, SelectField } from "@/components/ui/form";
import { routes } from "@/config/routes";
import {
  countries,
  regionsForCountry,
  normalizeCountry,
} from "@/features/candidate/constants";
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
  const [preferred, setPreferred] = useState(normalizeCountry(preferredCountry ?? "") || "UAE");
  const currentRegions = useMemo(() => regionsForCountry(current), [current]);
  const preferredRegions = useMemo(() => regionsForCountry(preferred), [preferred]);

  return (
    <form action={saveLocationDetails} className="grid gap-4">
      <input type="hidden" name="next" value={next} />
      <label className="grid gap-2">
        <Label>Current residence country</Label>
        <SelectField
          name="currentCountry"
          value={current}
          onChange={(event) => setCurrent(event.target.value)}
        >
          {countries.map((country) => (
            <option key={country}>{country}</option>
          ))}
        </SelectField>
      </label>
      <label className="grid gap-2">
        <Label>{current === "India" ? "Current Indian state" : "Current emirate"}</Label>
        <SelectField name="currentRegion" defaultValue={currentRegion ?? ""} key={current}>
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
          onChange={(event) => setPreferred(event.target.value)}
        >
          {countries.map((country) => (
            <option key={country}>{country}</option>
          ))}
        </SelectField>
      </label>
      <label className="grid gap-2">
        <Label>{preferred === "India" ? "Preferred Indian state" : "Preferred emirate"}</Label>
        <SelectField name="preferredRegion" defaultValue={preferredRegion ?? ""} key={preferred}>
          <option value="">Select</option>
          {preferredRegions.map((region) => (
            <option key={region}>{region}</option>
          ))}
        </SelectField>
      </label>
      <div className="sticky bottom-16 flex gap-3 bg-white/95 py-3 sm:static">
        <Button type="submit">Save and continue</Button>
      </div>
    </form>
  );
}
