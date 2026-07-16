import { ButtonLink } from "@/components/ui/button";
import { AdminPageHeader } from "@/features/admin/components/admin-ui";
import { AdminNotificationsClient } from "@/features/admin/notifications/admin-notifications-client";
import { loadAdminNotificationPageData } from "@/features/admin/notifications/server";

export default async function AdminNotificationsPage({
  searchParams,
}: {
  searchParams: Promise<{
    q?: string;
    status?: string;
    audience?: string;
    type?: string;
  }>;
}) {
  const params = await searchParams;
  const data = await loadAdminNotificationPageData(params);

  return (
    <div>
      <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <AdminPageHeader
          title="Send Notifications"
          description="Create and send announcements, alerts, and updates to KAAM users."
        />
        <ButtonLink href="#notification-history" variant="secondary" className="shrink-0">
          Notification History
        </ButtonLink>
      </div>
      <AdminNotificationsClient
        counts={data.counts}
        candidates={data.candidates}
        employers={data.employers}
        history={data.history}
        pushConfiguration={data.pushConfiguration}
        filters={params}
      />
    </div>
  );
}
