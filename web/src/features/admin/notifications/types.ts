export const audienceOptions = [
  { value: "all_users", label: "All users" },
  { value: "all_candidates", label: "All candidates" },
  { value: "all_employers", label: "All employers" },
  { value: "selected_candidates", label: "Selected candidates" },
  { value: "selected_employers", label: "Selected employers" },
  { value: "pending_documents", label: "Users with pending documents" },
  { value: "rejected_documents", label: "Users with rejected documents" },
  { value: "paid_candidates", label: "Paid candidates" },
  { value: "unpaid_candidates", label: "Unpaid candidates" },
  { value: "matched_users", label: "Matched users" },
  { value: "inactive_users", label: "Inactive users" },
] as const;

export const notificationTypeOptions = [
  { value: "admin_broadcast", label: "Admin broadcast" },
  { value: "general_announcement", label: "General announcement" },
  { value: "document_update", label: "Document update" },
  { value: "membership_update", label: "Membership update" },
  { value: "match_update", label: "Match update" },
  { value: "account_alert", label: "Account alert" },
  { value: "promotional", label: "Promotional" },
  { value: "maintenance", label: "Maintenance" },
  { value: "urgent_alert", label: "Urgent alert" },
] as const;

export const actionOptions = [
  { value: "none", label: "No action" },
  { value: "candidate_profile", label: "Open candidate profile" },
  { value: "employer_profile", label: "Open employer profile" },
  { value: "documents", label: "Open documents" },
  { value: "membership", label: "Open membership page" },
  { value: "matches", label: "Open matches" },
  { value: "chat", label: "Open chat" },
  { value: "custom_route", label: "Custom internal route" },
] as const;

export const statusOptions = [
  { value: "draft", label: "Draft" },
  { value: "scheduled", label: "Scheduled" },
  { value: "sending", label: "Processing" },
  { value: "sent", label: "Sent" },
  { value: "partially_sent", label: "Partially sent" },
  { value: "failed", label: "Failed" },
  { value: "no_eligible_devices", label: "No eligible devices" },
  { value: "cancelled", label: "Cancelled" },
] as const;

export type AudienceType = (typeof audienceOptions)[number]["value"];
export type AdminNotificationType =
  (typeof notificationTypeOptions)[number]["value"];
export type AdminNotificationStatus = (typeof statusOptions)[number]["value"];
export type AdminNotificationActionType =
  (typeof actionOptions)[number]["value"];
export type DeliveryChannel = "in_app" | "push" | "email" | "whatsapp";

export type AdminNotificationRow = {
  id: string;
  title: string;
  message: string;
  notification_type: AdminNotificationType;
  audience_type: AudienceType;
  audience_filters: Record<string, unknown> | null;
  action_type: AdminNotificationActionType;
  action_value: string | null;
  channels: DeliveryChannel[] | null;
  status: AdminNotificationStatus;
  recipient_count: number | null;
  scheduled_at: string | null;
  sent_at: string | null;
  created_by: string;
  sent_by: string | null;
  created_at: string;
  idempotency_key?: string | null;
  in_app_success_count?: number | null;
  push_eligible_device_count?: number | null;
  push_success_count?: number | null;
  push_failure_count?: number | null;
  push_skipped_count?: number | null;
  failure_summary?: string | null;
  profiles?: { email: string | null; full_name: string | null } | null;
};

export type AudienceCounts = Record<AudienceType, number | null>;

export type SelectableUser = {
  id: string;
  label: string;
  email: string | null;
  activeAndroidDeviceCount: number;
};

export type PushReadinessStatus =
  | "READY"
  | "NO_SESSION"
  | "TOKEN_MISSING"
  | "NOT_ADMIN"
  | "EDGE_UNAUTHORIZED"
  | "FUNCTION_MISSING"
  | "SERVER_CONFIG_MISSING"
  | "SCHEMA_MISSING"
  | "UNREACHABLE"
  | "UNAUTHORIZED"
  | "UNKNOWN";

export type PushConfiguration = {
  configured: boolean;
  status: PushReadinessStatus;
  reason: string;
  setupHint: string;
  httpStatus?: number;
};

export type AdminNotificationActionState = {
  ok: boolean;
  message: string;
  code?: string;
  broadcastId?: string;
  inAppRecipientCount?: number;
  pushEligibleDeviceCount?: number;
  scheduled?: boolean;
  warning?: string;
  idempotencyKey?: string;
};

export const initialAdminNotificationActionState: AdminNotificationActionState =
  {
    ok: false,
    message: "",
  };
