import { PageTitle } from "@/components/layout/page-title";
import { SearchFilterFoundation } from "@/features/employer/search-filter-foundation";

export default function EmployerSearchPage() {
  return (
    <div className="grid gap-6">
      <PageTitle title="Search candidates" description="Start with skill category, then narrow by location, experience, availability, and verification." />
      <SearchFilterFoundation />
    </div>
  );
}
