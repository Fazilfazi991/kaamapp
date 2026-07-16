import { Button } from "@/components/ui/button";
import { EmptyStateCard } from "@/components/ui/empty-state";
import type { UserRole } from "@/types/domain";
import type { NotificationPreferencesRow, NotificationRow } from "./model";
import {
  markAllNotificationsReadAction,
  openNotificationAction,
  saveNotificationPreferencesAction,
} from "./server";

export function NotificationCenter({
  userId,
  role,
  notifications,
  preferences,
  currentPath,
}: {
  userId: string;
  role: UserRole;
  notifications: NotificationRow[];
  preferences: NotificationPreferencesRow;
  currentPath: string;
}) {
  const unreadCount = notifications.filter((item) => item.status === "unread").length;

  return (
    <div className="grid gap-5">
      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-2xl font-semibold text-[#201925]">Notifications</h1>
            <p className="mt-1 text-sm text-[#66616f]">{unreadCount} unread</p>
          </div>
          <form action={markAllNotificationsReadAction}>
            <input type="hidden" name="userId" value={userId} />
            <input type="hidden" name="currentPath" value={currentPath} />
            <Button type="submit" variant="secondary" disabled={unreadCount === 0}>
              Mark all read
            </Button>
          </form>
        </div>
      </section>

      {notifications.length === 0 ? (
        <EmptyStateCard
          title="No notifications yet"
          description="Account, message, match, and verification updates will appear here."
        />
      ) : (
        <section className="grid gap-3">
          {notifications.map((notification) => (
            <article
              key={notification.id}
              className={`rounded-lg border bg-white p-4 shadow-sm ${
                notification.status === "unread"
                  ? "border-[#e53670]"
                  : "border-[#eadde3]"
              }`}
            >
              <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <p className="text-sm font-semibold text-[#201925]">
                    {notification.title}
                  </p>
                  <p className="mt-1 text-sm leading-6 text-[#66616f]">
                    {notification.body}
                  </p>
                  <p className="mt-2 text-xs font-medium text-[#8a7c88]">
                    {new Date(notification.created_at).toLocaleDateString()}
                  </p>
                </div>
                <form action={openNotificationAction}>
                  <input type="hidden" name="notificationId" value={notification.id} />
                  <input type="hidden" name="role" value={role} />
                  <input type="hidden" name="type" value={notification.type} />
                  <input
                    type="hidden"
                    name="actionRoute"
                    value={notification.action_route ?? ""}
                  />
                  <input type="hidden" name="currentPath" value={currentPath} />
                  <Button type="submit" variant="secondary" className="min-h-10 px-3 py-2">
                    View
                  </Button>
                </form>
              </div>
            </article>
          ))}
        </section>
      )}

      <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
        <h2 className="text-lg font-semibold text-[#201925]">Preferences</h2>
        <form action={saveNotificationPreferencesAction} className="mt-4 grid gap-3">
          <input type="hidden" name="userId" value={userId} />
          <input type="hidden" name="currentPath" value={currentPath} />
          <PreferenceCheckbox name="push_enabled" label="Push notifications" checked={preferences.push_enabled} />
          <PreferenceCheckbox name="in_app_enabled" label="In-app notifications" checked={preferences.in_app_enabled} />
          <PreferenceCheckbox name="new_messages_enabled" label="New messages" checked={preferences.new_messages_enabled} />
          <PreferenceCheckbox
            name="interests_and_matches_enabled"
            label="Interests and matches"
            checked={preferences.interests_and_matches_enabled}
          />
          <PreferenceCheckbox
            name="document_updates_enabled"
            label="Document and verification updates"
            checked={preferences.document_updates_enabled}
          />
          <PreferenceCheckbox
            name="account_security_enabled"
            label="Account and security updates"
            checked={preferences.account_security_enabled}
          />
          <Button type="submit" className="mt-2 w-fit">
            Save preferences
          </Button>
        </form>
      </section>
    </div>
  );
}

function PreferenceCheckbox({
  name,
  label,
  checked,
}: {
  name: string;
  label: string;
  checked: boolean;
}) {
  return (
    <label className="flex items-center gap-3 text-sm font-medium text-[#3b3340]">
      <input
        name={name}
        type="checkbox"
        defaultChecked={checked}
        className="h-4 w-4 rounded border-[#d8c9d2] text-[#e53670]"
      />
      {label}
    </label>
  );
}
