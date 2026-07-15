import { Button } from "@/components/ui/button";
import { SelectField, TextInput } from "@/components/ui/form";
import { indianStates, uaeEmirates } from "@/features/candidate/constants";
import { saveCompanyContact, saveCompanyInformation, saveCompanyLocation, uploadCompanyLogo } from "@/features/employer/server/profile-actions";
import { companySizeOptions, employerIndustryOptions } from "./validation";
import type { EmployerCompany } from "@/features/employer/types";

export function CompanyInformationForm({ company, next = "/employer/onboarding/location" }: { company: EmployerCompany | null; next?: string }) {
  return (
    <form action={saveCompanyInformation} className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <input type="hidden" name="next" value={next} />
      <h2 className="text-lg font-semibold text-[#201925]">Company information</h2>
      <div className="mt-5 grid gap-4 md:grid-cols-2">
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">Legal company name<TextInput name="companyName" defaultValue={company?.company_name ?? ""} required /></label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">Trade licence number<TextInput name="tradeLicenseNumber" defaultValue={company?.trade_license_number ?? ""} required /></label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">Industry<SelectField name="industry" defaultValue={company?.industry ?? ""} required><option value="">Select industry</option>{employerIndustryOptions.map((item) => <option key={item}>{item}</option>)}</SelectField></label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">Company size<SelectField name="companySize" defaultValue={company?.company_size ?? ""} required><option value="">Select size</option>{companySizeOptions.map((item) => <option key={item}>{item}</option>)}</SelectField></label>
      </div>
      <label className="mt-4 grid gap-2 text-sm font-semibold text-[#342b38]">Company description<textarea name="description" defaultValue={company?.description ?? ""} rows={4} className="focus-ring rounded-lg border border-[#dfd2d9] px-4 py-3 text-base text-[#201925]" /></label>
      <div className="mt-5"><Button type="submit">Save and continue</Button></div>
    </form>
  );
}

export function CompanyLocationForm({ company, next = "/employer/onboarding/contact" }: { company: EmployerCompany | null; next?: string }) {
  const country = company?.country === "India" ? "India" : "UAE";
  const regions = country === "India" ? indianStates : uaeEmirates;
  return (
    <form action={saveCompanyLocation} className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <input type="hidden" name="next" value={next} />
      <h2 className="text-lg font-semibold text-[#201925]">Company location</h2>
      <div className="mt-5 grid gap-4 md:grid-cols-2">
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">Country<SelectField name="country" defaultValue={country}><option value="UAE">United Arab Emirates</option><option value="India">India</option></SelectField></label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">{country === "India" ? "State / UT" : "Emirate"}<SelectField name="region" defaultValue={company?.city ?? ""} required><option value="">Select region</option>{regions.map((item) => <option key={item}>{item}</option>)}</SelectField></label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38] md:col-span-2">Office area / branch<TextInput name="officeArea" defaultValue={company?.office_area ?? ""} /></label>
      </div>
      <p className="mt-3 text-sm text-[#66616f]">Changing country clears stale hidden region values on save.</p>
      <div className="mt-5"><Button type="submit">Save and continue</Button></div>
    </form>
  );
}

export function CompanyContactForm({ company, next = "/employer/onboarding/documents" }: { company: EmployerCompany | null; next?: string }) {
  return (
    <form action={saveCompanyContact} className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <input type="hidden" name="next" value={next} />
      <h2 className="text-lg font-semibold text-[#201925]">Contact details</h2>
      <p className="mt-2 text-sm text-[#66616f]">Private contact details are not shown to candidates before the allowed match/contact state.</p>
      <div className="mt-5 grid gap-4 md:grid-cols-2">
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">Contact person<TextInput name="contactPerson" defaultValue={company?.contact_person ?? ""} required /></label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">Designation<TextInput name="contactRole" defaultValue={company?.contact_role ?? ""} required /></label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">Company phone<TextInput name="companyPhone" placeholder="+971..." /></label>
        <label className="grid gap-2 text-sm font-semibold text-[#342b38]">Website<TextInput name="website" defaultValue={company?.website ?? ""} placeholder="https://example.com" /></label>
      </div>
      <div className="mt-5"><Button type="submit">Save and continue</Button></div>
    </form>
  );
}

export function CompanyLogoForm() {
  return (
    <form action={uploadCompanyLogo} className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <h2 className="text-lg font-semibold text-[#201925]">Company logo</h2>
      <input className="mt-4 block text-sm" type="file" name="logo" accept="image/jpeg,image/png,image/webp" />
      <div className="mt-5"><Button type="submit" variant="secondary">Upload logo</Button></div>
    </form>
  );
}
