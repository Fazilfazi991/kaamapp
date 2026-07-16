import { routes } from "@/config/routes";
import type { UserRole } from "@/types/domain";

export type NotificationRow = {
  id: string;
  type: string;
  title: string;
  body: string;
  status: "unread" | "read" | "archived";
  read_at: string | null;
  created_at: string;
  action_route: string | null;
  data: Record<string, unknown> | null;
};

export type NotificationPreferencesRow = {
  push_enabled: boolean;
  in_app_enabled: boolean;
  email_enabled: boolean;
  whatsapp_enabled: boolean;
  new_messages_enabled: boolean;
  interests_and_matches_enabled: boolean;
  document_updates_enabled: boolean;
  account_security_enabled: boolean;
};

const safeRoutesByRole: Record<UserRole, Set<string>> = {
  candidate: new Set([
    routes.candidateNotifications,
    routes.candidateInterests,
    routes.candidateMatches,
    routes.candidateMessages,
    routes.candidateDocuments,
    routes.candidateMembership,
    routes.candidateProfileEdit,
  ]),
  employer: new Set([
    routes.employerNotifications,
    routes.employerInterests,
    routes.employerMatches,
    routes.employerMessages,
    routes.employerDocuments,
    routes.employerProfile,
    routes.employerShortlist,
  ]),
  admin: new Set([
    routes.adminNotifications,
    "/admin/candidate-documents",
    "/admin/employer-documents",
    "/admin/employers",
    "/admin/candidates",
    "/admin/reports",
  ]),
};

const fallbackByRole: Record<UserRole, string> = {
  candidate: routes.candidateNotifications,
  employer: routes.employerNotifications,
  admin: routes.adminNotifications,
};

export function safeNotificationHref({
  role,
  type,
  actionRoute,
}: {
  role: UserRole;
  type: string;
  actionRoute?: string | null;
}) {
  const direct = allowlistedRoute(role, actionRoute);
  if (direct) return direct;

  if (role === "candidate") {
    if (type.includes("interest")) return routes.candidateInterests;
    if (type.includes("match")) return routes.candidateMatches;
    if (type.includes("message")) return routes.candidateMessages;
    if (type.includes("document")) return routes.candidateDocuments;
    if (type.includes("membership")) return routes.candidateMembership;
    if (type === "profile_incomplete") return routes.candidateProfileEdit;
  }

  if (role === "employer") {
    if (type.includes("interest")) return routes.employerInterests;
    if (type.includes("match")) return routes.employerMatches;
    if (type.includes("message")) return routes.employerMessages;
    if (type.includes("document")) return routes.employerDocuments;
    if (type.includes("company")) return routes.employerProfile;
  }

  if (role === "admin") {
    if (type === "candidate_document_submitted") return "/admin/candidate-documents";
    if (type === "employer_document_submitted") return "/admin/employer-documents";
    if (type === "company_review_submitted") return "/admin/employers";
    if (type === "report_received") return "/admin/reports";
  }

  return fallbackByRole[role];
}

export function sanitizePushPayload(data: Record<string, unknown>) {
  const sensitive = new Set([
    "passport_number",
    "dob",
    "date_of_birth",
    "phone",
    "email",
    "storage_path",
    "signed_url",
    "otp",
    "access_token",
    "message_body",
  ]);
  return Object.fromEntries(
    Object.entries(data)
      .filter(([key, value]) => !sensitive.has(key) && value != null)
      .map(([key, value]) => [key, String(value)]),
  );
}

function allowlistedRoute(role: UserRole, route?: string | null) {
  if (!route) return null;
  const trimmed = route.trim();
  if (!trimmed.startsWith("/") || trimmed.startsWith("//") || trimmed.includes("://")) {
    return null;
  }
  return safeRoutesByRole[role].has(trimmed) ? trimmed : null;
}
