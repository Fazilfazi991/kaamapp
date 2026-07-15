"use client";

import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { SelectField } from "@/components/ui/form";
import { EmptyStateCard } from "@/components/ui/empty-state";

const categories = {
  Construction: ["Mason", "Electrician", "Plumber", "Painter"],
  Cleaning: ["Housekeeping", "Office Cleaning", "Deep Cleaning"],
  Hospitality: ["Waiter", "Kitchen Helper", "Steward"],
  "Driving and Delivery": ["Driver", "Bike Delivery", "Warehouse Picker"],
  Maintenance: ["AC Technician", "General Maintenance", "Carpenter"],
  Security: ["Security Guard", "CCTV Operator"],
  Retail: ["Sales Assistant", "Cashier", "Store Helper"],
  "Domestic Work": ["Nanny", "Cook", "Domestic Helper"],
};

const states = {
  UAE: ["Dubai", "Abu Dhabi", "Sharjah", "Ajman", "Ras Al Khaimah", "Fujairah", "Umm Al Quwain"],
  India: ["Kerala", "Tamil Nadu", "Karnataka", "Maharashtra", "Telangana", "Delhi", "Punjab"],
};

export function SearchFilterFoundation() {
  const [category, setCategory] = useState("Construction");
  const [country, setCountry] = useState<"UAE" | "India">("UAE");
  const skillOptions = useMemo(() => categories[category as keyof typeof categories], [category]);
  const locationOptions = states[country];

  return (
    <div className="grid gap-5">
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <div className="grid gap-4 md:grid-cols-2">
          <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
            Main skill category
            <SelectField value={category} onChange={(event) => setCategory(event.target.value)}>
              {Object.keys(categories).map((item) => (
                <option key={item}>{item}</option>
              ))}
            </SelectField>
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
            Subcategory or skill
            <SelectField>
              {skillOptions.map((item) => (
                <option key={item}>{item}</option>
              ))}
            </SelectField>
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
            Country
            <SelectField value={country} onChange={(event) => setCountry(event.target.value as "UAE" | "India")}>
              <option>UAE</option>
              <option>India</option>
            </SelectField>
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
            {country === "UAE" ? "Emirate" : "Indian state"}
            <SelectField>
              {locationOptions.map((item) => (
                <option key={item}>{item}</option>
              ))}
            </SelectField>
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
            Experience
            <SelectField>
              <option>Any experience</option>
              <option>0-1 years</option>
              <option>1-3 years</option>
              <option>3+ years</option>
            </SelectField>
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[#342b38]">
            Availability
            <SelectField>
              <option>Any availability</option>
              <option>Available immediately</option>
              <option>Within 15 days</option>
              <option>Within 30 days</option>
            </SelectField>
          </label>
        </div>
        <label className="mt-4 flex items-center gap-3 text-sm font-semibold text-[#342b38]">
          <input type="checkbox" className="h-5 w-5 accent-[#e53670]" />
          Verified profile only
        </label>
        <div className="mt-5 flex flex-wrap gap-3">
          <Button type="button">Search</Button>
          <Button type="button" variant="secondary">Clear filters</Button>
        </div>
      </section>

      <EmptyStateCard
        title="No candidates loaded"
        description="This phase creates the search interface only. Candidate results will be connected after the existing public candidate search contract is confirmed for web."
      />
    </div>
  );
}
