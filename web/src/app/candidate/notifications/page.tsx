import { NotificationCenter } from "@/features/notifications/notification-center";
import {
  loadNotificationPreferences,
  loadNotificationsForUser,
} from "@/features/notifications/server";
import { requireRole } from "@/lib/auth/session";

export default async function CandidateNotificationsPage() {
  const account = await requireRole("candidate");
  const [notifications, preferences] = await Promise.all([
    loadNotificationsForUser({ userId: account.userId }),
    loadNotificationPreferences(account.userId),
  ]);

  return (
    <NotificationCenter
      userId={account.userId}
      role="candidate"
      notifications={notifications}
      preferences={preferences}
      currentPath="/candidate/notifications"
    />
  );
}
