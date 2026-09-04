import type { PublicHiringRequirement } from "@/features/public-jobs/types";

// TEMPORARY QA FIXTURES — NEVER USE AS PRODUCTION JOB DATA.
// These records are returned only when the server-side KAAM_PUBLIC_JOBS_DEMO flag is exactly "true".
export const demoPublicHiringRequirements: PublicHiringRequirement[] = [
  { id: "demo-parotta-maker-karama", role: "Parotta Maker", custom_role: null, openings: 12, work_location: "Karama, Dubai", application_deadline: "2026-09-25", created_at: "2026-09-04T10:00:00.000Z" },
  { id: "demo-ac-mechanic-doha", role: "AC Mechanic", custom_role: null, openings: 8, work_location: "Doha, Qatar", application_deadline: "2026-09-28", created_at: "2026-09-04T09:00:00.000Z" },
  { id: "demo-driver-sharjah", role: "Driver", custom_role: null, openings: 20, work_location: "Sharjah, UAE", application_deadline: "2026-09-30", created_at: "2026-09-04T08:00:00.000Z" },
  { id: "demo-housekeeping-abu-dhabi", role: "Housekeeping", custom_role: null, openings: 15, work_location: "Abu Dhabi, UAE", application_deadline: "2026-10-02", created_at: "2026-09-04T07:00:00.000Z" },
  { id: "demo-store-keeper-al-ain", role: "Store Keeper", custom_role: null, openings: 10, work_location: "Al Ain, UAE", application_deadline: "2026-10-04", created_at: "2026-09-04T06:00:00.000Z" },
  { id: "demo-building-electrician-ruwais", role: "Building Electrician", custom_role: null, openings: 14, work_location: "Ruwais, UAE", application_deadline: "2026-10-05", created_at: "2026-09-04T05:00:00.000Z" },
  { id: "demo-waiter-dubai-marina", role: "Waiter", custom_role: null, openings: 10, work_location: "Dubai Marina, Dubai", application_deadline: "2026-10-06", created_at: "2026-09-04T04:00:00.000Z" },
  { id: "demo-plumber-ajman", role: "Plumber", custom_role: null, openings: 6, work_location: "Ajman, UAE", application_deadline: "2026-10-08", created_at: "2026-09-04T03:00:00.000Z" },
  { id: "demo-delivery-rider-deira", role: "Delivery Rider", custom_role: null, openings: 18, work_location: "Deira, Dubai", application_deadline: "2026-10-10", created_at: "2026-09-04T02:00:00.000Z" },
  { id: "demo-kitchen-helper-muscat", role: "Kitchen Helper", custom_role: null, openings: 9, work_location: "Muscat, Oman", application_deadline: "2026-10-12", created_at: "2026-09-04T01:00:00.000Z" },
];
