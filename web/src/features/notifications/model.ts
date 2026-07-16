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
  ]),
  employer: new Set([
    routes.employerNotifications,
    routes.employerInterests,
    routes.employerMatches,
    routes.employerMessages,
    routes.employerDocuments,
    routes.employerProfile,
  ]),
  admin: new Set([
    routes.adminNotifications,
    "/admin/candidate-documents",
    "/admin/employer-documents",
    "/admin/employers",
    "/admin/candidates",
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
    if (candidateInterestTypes.has(type)) return routes.candidateInterests;
    if (type === "match_created") return routes.candidateMatches;
    if (type === "new_message") return routes.candidateMessages;
    if (candidateDocumentTypes.has(type)) return routes.candidateDocuments;
  }

  if (role === "employer") {
    if (employerInterestTypes.has(type)) return routes.employerInterests;
    if (type === "match_created") return routes.employerMatches;
    if (type === "new_message") return routes.employerMessages;
    if (employerDocumentTypes.has(type)) return routes.employerDocuments;
    if (employerCompanyTypes.has(type)) return routes.employerProfile;
  }

  if (role === "admin") {
    if (type === "candidate_document_submitted") return "/admin/candidate-documents";
    if (type === "employer_document_submitted") return "/admin/employer-documents";
    if (type === "company_review_submitted") return "/admin/employers";
  }

  return fallbackByRole[role];
}

const candidateInterestTypes = new Set([
  "employer_interest_received",
  "interest_accepted",
  "interest_rejected",
]);

const candidateDocumentTypes = new Set([
  "candidate_document_pending",
  "candidate_document_approved",
  "candidate_document_rejected",
  "candidate_document_resubmission_requested",
]);

const employerInterestTypes = new Set([
  "candidate_accepted_interest",
  "candidate_rejected_interest",
]);

const employerDocumentTypes = new Set([
  "employer_document_approved",
  "employer_document_rejected",
]);

const employerCompanyTypes = new Set(["company_approved", "company_rejected"]);

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
