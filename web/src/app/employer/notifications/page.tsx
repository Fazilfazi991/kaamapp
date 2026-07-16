import { NotificationCenter } from "@/features/notifications/notification-center";
import {
  loadNotificationPreferences,
  loadNotificationsForUser,
} from "@/features/notifications/server";
import { requireRole } from "@/lib/auth/session";

export default async function EmployerNotificationsPage() {
  const account = await requireRole("employer");
  const [notifications, preferences] = await Promise.all([
    loadNotificationsForUser({ userId: account.userId }),
    loadNotificationPreferences(account.userId),
  ]);

  return (
    <NotificationCenter
      userId={account.userId}
      role="employer"
      notifications={notifications}
      preferences={preferences}
      currentPath="/employer/notifications"
    />
  );
}
