import { NextResponse } from "next/server";
import { requireAdmin } from "@/features/admin/auth/require-admin";
import { loadAnalytics, type AnalyticsRange } from "@/features/admin/analytics/server";
const valid = new Set<AnalyticsRange>(["today","yesterday","7d","30d","month","previous-month","custom"]);
const escape = (value: unknown) => `"${String(value ?? "").replaceAll('"', '""')}"`;
export async function GET(request: Request) {
  await requireAdmin();
  const url = new URL(request.url); const requested = url.searchParams.get("range") as AnalyticsRange; const range = valid.has(requested) ? requested : "30d"; const type = url.searchParams.get("type") ?? "visitors"; const data = await loadAnalytics(range, url.searchParams.get("start") ?? undefined, url.searchParams.get("end") ?? undefined);
  const rows = type === "registrations" ? [["name","email","role","registered_at","source","medium","campaign"], ...data.registrations.map((row) => [row.full_name,row.email,row.role,row.created_at,row.acquisition?.first_source ?? "Unknown / Pre-analytics",row.acquisition?.first_medium ?? "",row.acquisition?.first_campaign ?? ""])] : type === "acquisition" ? [["source","sessions"], ...data.sources.map((row) => [row.label,row.value])] : type === "pages" ? [["page","page_views"], ...data.pages.map((row) => [row.label,row.value])] : [["anonymous_visitor","first_seen_at","source","medium","campaign","landing_page","country","city","registered_user_id"], ...data.visitors.map((row) => [row.anonymous_id,row.first_seen_at,row.first_source,row.first_medium,row.first_campaign,row.first_landing_page,row.country,row.city,row.linked_user_id])];
  return new NextResponse(rows.map((row) => row.map(escape).join(",")).join("\n"), { headers: { "content-type": "text/csv; charset=utf-8", "content-disposition": `attachment; filename=kaam-${type}-${range}.csv` } });
}
