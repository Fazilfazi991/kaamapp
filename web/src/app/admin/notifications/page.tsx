import { NotificationCenter } from "@/features/notifications/notification-center";
import {
  loadNotificationPreferences,
  loadNotificationsForUser,
} from "@/features/notifications/server";
import { requireAdmin } from "@/features/admin/auth/require-admin";

export default async function AdminNotificationsPage() {
  const account = await requireAdmin();
  const [notifications, preferences] = await Promise.all([
    loadNotificationsForUser({ userId: account.userId, unreadOnly: true }),
    loadNotificationPreferences(account.userId),
  ]);

  return (
    <NotificationCenter
      userId={account.userId}
      role="admin"
      notifications={notifications}
      preferences={preferences}
      currentPath="/admin/notifications"
    />
  );
}
