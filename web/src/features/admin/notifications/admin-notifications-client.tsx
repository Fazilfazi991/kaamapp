"use client";

import { type FormEvent, useState } from "react";
import { Button } from "@/components/ui/button";
import {
  AdminStatus,
  AdminTable,
  SafeLink,
} from "@/features/admin/components/admin-ui";
import { createAdminNotificationAction } from "./server";
import {
  audienceSupportsPush,
  canEnablePushChannel,
  pushReadinessLabel,
  selectedActiveAndroidDeviceCount,
} from "./logic";
import {
  actionOptions,
  audienceOptions,
  type AudienceCounts,
  type AudienceType,
  type DeliveryChannel,
  initialAdminNotificationActionState,
  type AdminNotificationRow,
  notificationTypeOptions,
  type PushConfiguration,
  type SelectableUser,
  statusOptions,
} from "./types";

export function AdminNotificationsClient({
  counts,
  candidates,
  employers,
  history,
  pushConfiguration,
  filters,
}: {
  counts: AudienceCounts;
  candidates: SelectableUser[];
  employers: SelectableUser[];
  history: AdminNotificationRow[];
  pushConfiguration: PushConfiguration;
  filters: { q?: string; status?: string; audience?: string; type?: string };
}) {
  const [state, setState] = useState(initialAdminNotificationActionState);
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [audienceType, setAudienceType] = useState<AudienceType>("all_users");
  const [notificationType, setNotificationType] = useState(
    "general_announcement",
  );
  const [actionType, setActionType] = useState("none");
  const [actionValue, setActionValue] = useState("");
  const [scheduleMode, setScheduleMode] = useState<"now" | "later">("now");
  const [scheduledAt, setScheduledAt] = useState("");
  const [channels, setChannels] = useState<DeliveryChannel[]>(["in_app"]);
  const [candidateSearch, setCandidateSearch] = useState("");
  const [employerSearch, setEmployerSearch] = useState("");
  const [selectedUserIds, setSelectedUserIds] = useState<string[]>([]);
  const [confirmMode, setConfirmMode] = useState<"test" | "send" | null>(null);
  const [idempotencyKey, setIdempotencyKey] = useState("");
  const [clientError, setClientError] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const selectedOptions =
    audienceType === "selected_candidates"
      ? candidates
      : audienceType === "selected_employers"
        ? employers
        : [];
  const filteredSelectedOptions = selectedOptions.filter((user) =>
    `${user.label} ${user.email ?? ""}`
      .toLowerCase()
      .includes(
        (audienceType === "selected_candidates"
          ? candidateSearch
          : employerSearch
        ).toLowerCase(),
      ),
  );
  const recipientCount =
    audienceType === "selected_candidates" ||
    audienceType === "selected_employers"
      ? selectedUserIds.length
      : (counts[audienceType] ?? 0);
  const selectedAudienceLabel =
    audienceOptions.find((option) => option.value === audienceType)?.label ??
    "Audience";
  const selectedAudienceSupportsPush = audienceSupportsPush(audienceType);
  const activeAndroidDeviceCount = selectedActiveAndroidDeviceCount(
    selectedOptions,
    selectedUserIds,
  );
  const pushChannelEnabled = canEnablePushChannel({
    audienceType,
    pushConfiguration,
    selectedUsers: selectedOptions,
    selectedUserIds,
  });
  const availableChannels = channels.filter(
    (channel) =>
      channel !== "push" ||
      (pushConfiguration.configured && selectedAudienceSupportsPush),
  );
  const selectedChannelLabels = channelOptions
    .filter((option) => availableChannels.includes(option.value))
    .map((option) => option.label);
  const canSubmit =
    title.trim().length > 0 &&
    message.trim().length > 0 &&
    availableChannels.length > 0 &&
    !isSubmitting;

  const hiddenFields = (
    <>
      <input type="hidden" name="title" value={title} />
      <input type="hidden" name="message" value={message} />
      <input type="hidden" name="audienceType" value={audienceType} />
      <input type="hidden" name="notificationType" value={notificationType} />
      <input type="hidden" name="actionType" value={actionType} />
      <input type="hidden" name="actionValue" value={actionValue} />
      <input type="hidden" name="scheduleMode" value={scheduleMode} />
      <input type="hidden" name="scheduledAt" value={scheduledAt} />
      <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
      {availableChannels.map((channel) => (
        <input key={channel} type="hidden" name="channels" value={channel} />
      ))}
      {selectedUserIds.map((id) => (
        <input key={id} type="hidden" name="selectedUserIds" value={id} />
      ))}
    </>
  );

  async function submitWithMode(mode: "draft" | "test" | "send") {
    if (isSubmitting) return;
    const submissionKey =
      mode === "draft"
        ? createIdempotencyKey()
        : idempotencyKey || createIdempotencyKey();
    const formData = new FormData();
    formData.set("mode", mode);
    formData.set("title", title);
    formData.set("message", message);
    formData.set("audienceType", audienceType);
    formData.set("notificationType", notificationType);
    formData.set("actionType", actionType);
    formData.set("actionValue", actionValue);
    formData.set("scheduleMode", scheduleMode);
    formData.set("scheduledAt", scheduledAt);
    formData.set("idempotencyKey", submissionKey);
    availableChannels.forEach((channel) =>
      formData.append("channels", channel),
    );
    selectedUserIds.forEach((id) => formData.append("selectedUserIds", id));
    setIsSubmitting(true);
    setClientError("");
    try {
      const result = await createAdminNotificationAction(state, formData);
      setState(result);
      if (result.ok) {
        setConfirmMode(null);
        resetComposer();
      }
    } catch {
      setState({
        ok: false,
        code: "BROADCAST_CREATE_FAILED",
        message: "Could not submit notification. Please try again.",
      });
    } finally {
      setIsSubmitting(false);
    }
  }

  function requestConfirmation(mode: "test" | "send") {
    setClientError("");
    if (availableChannels.length === 0) {
      setClientError("Select at least one notification channel.");
      return;
    }
    if (mode === "send" && recipientCount === 0) {
      setClientError("No recipients match this audience.");
      return;
    }
    if (scheduleMode === "later" && !scheduledAt) {
      setClientError("Select a scheduled date and time.");
      return;
    }
    if (availableChannels.includes("push") && !selectedAudienceSupportsPush) {
      setClientError("Push notifications must target selected QA users only.");
      return;
    }
    if (availableChannels.includes("push") && selectedUserIds.length === 0) {
      setClientError("Select one QA user before enabling push.");
      return;
    }
    if (
      availableChannels.includes("push") &&
      activeAndroidDeviceCount === 0
    ) {
      setClientError("No registered Android device");
      return;
    }
    setIdempotencyKey(createIdempotencyKey());
    setConfirmMode(mode);
  }

  function handleConfirmSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (confirmMode) void submitWithMode(confirmMode);
  }

  function toggleChannel(channel: DeliveryChannel, checked: boolean) {
    setClientError("");
    if (channel === "push" && !pushConfiguration.configured) {
      setChannels((current) => current.filter((item) => item !== "push"));
      setClientError(pushConfiguration.reason);
      return;
    }
    if (channel === "push" && checked && !selectedAudienceSupportsPush) {
      setChannels((current) => current.filter((item) => item !== "push"));
      setClientError("Push notifications must target selected QA users only.");
      return;
    }
    if (channel === "push" && checked && selectedUserIds.length === 0) {
      setChannels((current) => current.filter((item) => item !== "push"));
      setClientError("Select one QA user before enabling push.");
      return;
    }
    if (channel === "push" && checked && activeAndroidDeviceCount === 0) {
      setChannels((current) => current.filter((item) => item !== "push"));
      setClientError("No registered Android device");
      return;
    }
    setChannels((current) =>
      checked
        ? [...current, channel]
        : current.filter((item) => item !== channel),
    );
  }

  function resetComposer() {
    setTitle("");
    setMessage("");
    setAudienceType("all_users");
    setNotificationType("general_announcement");
    setActionType("none");
    setActionValue("");
    setScheduleMode("now");
    setScheduledAt("");
    setChannels(["in_app"]);
    setSelectedUserIds([]);
    setCandidateSearch("");
    setEmployerSearch("");
    setIdempotencyKey("");
    setClientError("");
  }

  return (
    <div className="grid gap-6">
      {clientError ? (
        <div className="rounded-lg border border-[#f1b6c8] bg-[#fff4f7] p-4 text-sm font-medium text-[#8f1741]">
          {clientError}
        </div>
      ) : null}

      {state.message ? (
        <div
          className={`rounded-lg border p-4 text-sm font-medium ${state.ok ? "border-[#a8d8ba] bg-[#f1fbf5] text-[#246b3d]" : "border-[#f1b6c8] bg-[#fff4f7] text-[#8f1741]"}`}
        >
          {state.message}
        </div>
      ) : null}

      <div className="grid gap-5 xl:grid-cols-[minmax(0,1.35fr)_minmax(320px,0.65fr)]">
        <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
          <h2 className="text-lg font-semibold text-[#201925]">
            Create notification
          </h2>
          <div className="mt-5 grid gap-4">
            <label className="grid gap-2 text-sm font-semibold text-[#3b3340]">
              Notification title
              <input
                value={title}
                onChange={(event) => setTitle(event.target.value)}
                placeholder="Enter notification title"
                maxLength={140}
                className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 font-normal"
              />
            </label>

            <label className="grid gap-2 text-sm font-semibold text-[#3b3340]">
              Message
              <textarea
                value={message}
                onChange={(event) => setMessage(event.target.value)}
                placeholder="Write the notification message..."
                maxLength={1200}
                rows={5}
                className="focus-ring min-h-32 rounded-lg border border-[#ded2da] px-3 py-3 font-normal"
              />
              <span className="text-xs font-medium text-[#8a7c88]">
                {message.length}/1200 characters
              </span>
            </label>

            <div className="grid gap-4 md:grid-cols-2">
              <label className="grid gap-2 text-sm font-semibold text-[#3b3340]">
                Audience
                <select
                  name="audience"
                  value={audienceType}
                  onChange={(event) => {
                    setAudienceType(event.target.value as AudienceType);
                    setSelectedUserIds([]);
                  }}
                  className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 font-normal"
                >
                  {audienceOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}{" "}
                      {counts[option.value] != null
                        ? `(${counts[option.value]})`
                        : ""}
                    </option>
                  ))}
                </select>
              </label>

              <label className="grid gap-2 text-sm font-semibold text-[#3b3340]">
                Notification type
                <select
                  value={notificationType}
                  onChange={(event) => setNotificationType(event.target.value)}
                  className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 font-normal"
                >
                  {notificationTypeOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>
            </div>

            {audienceType === "selected_candidates" ||
            audienceType === "selected_employers" ? (
              <div className="grid gap-2 rounded-lg border border-[#eadde3] bg-[#fff8fb] p-4">
                <label className="grid gap-2 text-sm font-semibold text-[#3b3340]">
                  Search and select users
                  <input
                    value={
                      audienceType === "selected_candidates"
                        ? candidateSearch
                        : employerSearch
                    }
                    onChange={(event) =>
                      audienceType === "selected_candidates"
                        ? setCandidateSearch(event.target.value)
                        : setEmployerSearch(event.target.value)
                    }
                    placeholder={`Search ${audienceType === "selected_candidates" ? "candidates" : "employers"}`}
                    className="focus-ring min-h-11 rounded-lg border border-[#ded2da] bg-white px-3 font-normal"
                  />
                </label>
                <div className="grid max-h-56 gap-2 overflow-auto pr-1">
                  {filteredSelectedOptions.map((user) => (
                    <label
                      key={user.id}
                      className="flex items-start gap-3 rounded-lg bg-white p-3 text-sm text-[#3b3340]"
                    >
                      <input
                        type="checkbox"
                        checked={selectedUserIds.includes(user.id)}
                        onChange={(event) =>
                          setSelectedUserIds((current) =>
                            event.target.checked
                              ? [...current, user.id]
                              : current.filter((id) => id !== user.id),
                          )
                        }
                        className="mt-1 h-4 w-4"
                      />
                      <span>
                        <span className="block font-semibold">
                          {user.label}
                        </span>
                        <span className="block text-xs text-[#8a7c88]">
                          {user.email ?? user.id}
                        </span>
                        <span className="block text-xs font-semibold text-[#8a7c88]">
                          {user.activeAndroidDeviceCount > 0
                            ? `${user.activeAndroidDeviceCount} active Android device${user.activeAndroidDeviceCount === 1 ? "" : "s"}`
                            : "No registered Android device"}
                        </span>
                      </span>
                    </label>
                  ))}
                </div>
                <p className="text-xs font-medium text-[#8a7c88]">
                  {selectedUserIds.length} selected
                </p>
              </div>
            ) : null}

            <fieldset className="grid gap-3">
              <legend className="text-sm font-semibold text-[#3b3340]">
                Delivery channel
              </legend>
              <div className="grid gap-2 md:grid-cols-2">
                {channelOptions.map((option) => (
                  <label
                    key={option.value}
                    className="flex items-center gap-3 rounded-lg border border-[#eadde3] p-3 text-sm font-medium text-[#3b3340]"
                  >
                    <input
                      type="checkbox"
                      checked={channels.includes(option.value)}
                      disabled={
                        option.value === "push" &&
                        !pushChannelEnabled
                      }
                      onChange={(event) =>
                        toggleChannel(option.value, event.target.checked)
                      }
                      className="h-4 w-4"
                    />
                    {option.label}
                    {option.value === "push" &&
                    !pushConfiguration.configured ? (
                      <span className="text-xs text-[#8a7c88]">
                        {pushReadinessLabel(pushConfiguration)}
                      </span>
                    ) : null}
                    {option.value === "push" &&
                    pushConfiguration.configured &&
                    !selectedAudienceSupportsPush ? (
                      <span className="text-xs text-[#8a7c88]">
                        Selected users only
                      </span>
                    ) : null}
                    {option.value === "push" &&
                    pushConfiguration.configured &&
                    selectedAudienceSupportsPush &&
                    selectedUserIds.length > 0 &&
                    activeAndroidDeviceCount === 0 ? (
                      <span className="text-xs text-[#8a7c88]">
                        No registered Android device
                      </span>
                    ) : null}
                    {option.value !== "in_app" && option.value !== "push" ? (
                      <span className="text-xs text-[#8a7c88]">
                        Not configured
                      </span>
                    ) : null}
                  </label>
                ))}
              </div>
              {!pushConfiguration.configured ? (
                <div className="flex flex-wrap items-center gap-2 text-xs font-medium text-[#8a7c88]">
                  <span>
                    Push readiness: {pushReadinessLabel(pushConfiguration)}.
                    {" "}
                    {pushConfiguration.reason} {pushConfiguration.setupHint}
                  </span>
                  <button
                    type="button"
                    className="font-semibold text-[#e53670] underline-offset-4 hover:underline"
                    onClick={() => window.location.reload()}
                  >
                    Retry
                  </button>
                </div>
              ) : null}
              {pushConfiguration.configured ? (
                <p className="text-xs font-medium text-[#8a7c88]">
                  Push readiness: {pushReadinessLabel(pushConfiguration)}. Push
                  is limited to explicitly selected QA users.
                  {selectedAudienceSupportsPush && selectedUserIds.length > 0
                    ? ` Active Android devices: ${activeAndroidDeviceCount}.`
                    : ""}
                </p>
              ) : null}
            </fieldset>

            <div className="grid gap-4 md:grid-cols-2">
              <label className="grid gap-2 text-sm font-semibold text-[#3b3340]">
                Action link
                <select
                  value={actionType}
                  onChange={(event) => setActionType(event.target.value)}
                  className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 font-normal"
                >
                  {actionOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>
              {actionType !== "none" ? (
                <label className="grid gap-2 text-sm font-semibold text-[#3b3340]">
                  Route or profile path
                  <input
                    value={actionValue}
                    onChange={(event) => setActionValue(event.target.value)}
                    placeholder="/candidate/profile"
                    className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 font-normal"
                  />
                </label>
              ) : null}
            </div>

            <fieldset className="grid gap-3">
              <legend className="text-sm font-semibold text-[#3b3340]">
                Schedule
              </legend>
              <div className="flex flex-wrap gap-3">
                <label className="flex items-center gap-2 text-sm font-medium text-[#3b3340]">
                  <input
                    type="radio"
                    checked={scheduleMode === "now"}
                    onChange={() => setScheduleMode("now")}
                  />
                  Send now
                </label>
                <label className="flex items-center gap-2 text-sm font-medium text-[#3b3340]">
                  <input
                    type="radio"
                    checked={scheduleMode === "later"}
                    onChange={() => setScheduleMode("later")}
                  />
                  Schedule for later
                </label>
              </div>
              {scheduleMode === "later" ? (
                <input
                  type="datetime-local"
                  value={scheduledAt}
                  onChange={(event) => setScheduledAt(event.target.value)}
                  className="focus-ring min-h-11 max-w-sm rounded-lg border border-[#ded2da] px-3 text-sm"
                />
              ) : null}
            </fieldset>

            <div className="flex flex-wrap gap-3 pt-2">
              <Button
                type="button"
                variant="secondary"
                disabled={!canSubmit}
                onClick={() => submitWithMode("draft")}
              >
                Save as draft
              </Button>
              <Button
                type="button"
                variant="secondary"
                disabled={!canSubmit}
                onClick={() => requestConfirmation("test")}
              >
                Send test notification
              </Button>
              <Button
                type="button"
                disabled={!canSubmit}
                onClick={() => requestConfirmation("send")}
              >
                Send notification
              </Button>
            </div>
          </div>
        </section>

        <NotificationPreview
          title={title}
          message={message}
          actionType={actionType}
        />
      </div>

      <NotificationHistory history={history} filters={filters} />

      {confirmMode ? (
        <div className="fixed inset-0 z-50 grid place-items-center bg-[#201925]/40 p-4">
          <section className="w-full max-w-lg rounded-lg bg-white p-5 shadow-xl">
            <h2 className="text-lg font-semibold text-[#201925]">
              {confirmMode === "test"
                ? "Send test notification?"
                : "Confirm and send?"}
            </h2>
            <dl className="mt-4 grid gap-3 text-sm">
              <SummaryItem label="Title" value={title} />
              <SummaryItem
                label="Audience"
                value={
                  confirmMode === "test"
                    ? "Your admin account"
                    : selectedAudienceLabel
                }
              />
              <SummaryItem
                label="Estimated recipients"
                value={String(confirmMode === "test" ? 1 : recipientCount)}
              />
              <SummaryItem
                label="Channels"
                value={selectedChannelLabels.join(", ")}
              />
              <SummaryItem
                label="Schedule"
                value={scheduleMode === "later" ? scheduledAt : "Send now"}
              />
            </dl>
            {!state.ok && state.message ? (
              <div className="mt-4 rounded-lg border border-[#f1b6c8] bg-[#fff4f7] p-3 text-sm font-medium text-[#8f1741]">
                {state.message}
              </div>
            ) : null}
            <form
              className="mt-5 flex flex-wrap justify-end gap-3"
              onSubmit={handleConfirmSubmit}
            >
              {hiddenFields}
              <input type="hidden" name="mode" value={confirmMode} />
              <Button
                type="button"
                variant="secondary"
                disabled={isSubmitting}
                onClick={() => setConfirmMode(null)}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={isSubmitting}>
                {isSubmitting
                  ? scheduleMode === "later"
                    ? "Scheduling..."
                    : "Sending..."
                  : "Confirm and send"}
              </Button>
            </form>
          </section>
        </div>
      ) : null}
    </div>
  );
}

function NotificationPreview({
  title,
  message,
  actionType,
}: {
  title: string;
  message: string;
  actionType: string;
}) {
  return (
    <aside className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <h2 className="text-lg font-semibold text-[#201925]">Preview</h2>
      <div className="mt-5 rounded-[28px] border border-[#201925] bg-[#f9f7f8] p-4">
        <div className="rounded-[22px] bg-white p-4 shadow-sm">
          <div className="flex items-center gap-2">
            <div className="grid h-9 w-9 place-items-center rounded-full bg-[#fff0f5] text-sm font-bold text-[#e53670]">
              K
            </div>
            <div>
              <p className="text-sm font-bold text-[#201925]">KAAM</p>
              <p className="text-xs text-[#8a7c88]">now</p>
            </div>
          </div>
          <p className="mt-4 text-sm font-semibold text-[#201925]">
            {title || "Notification title"}
          </p>
          <p className="mt-1 text-sm leading-6 text-[#66616f]">
            {message || "Write the notification message..."}
          </p>
          {actionType !== "none" ? (
            <button
              className="mt-4 min-h-10 rounded-lg bg-[#e53670] px-4 text-sm font-semibold text-white"
              type="button"
            >
              Open
            </button>
          ) : null}
        </div>
      </div>
    </aside>
  );
}

function NotificationHistory({
  history,
  filters,
}: {
  history: AdminNotificationRow[];
  filters: { q?: string; status?: string; audience?: string; type?: string };
}) {
  return (
    <section id="notification-history" className="grid gap-4">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h2 className="text-lg font-semibold text-[#201925]">
            Notification history
          </h2>
          <p className="mt-1 text-sm text-[#66616f]">
            Recent drafts, scheduled sends, and completed admin broadcasts.
          </p>
        </div>
      </div>
      <form className="grid gap-3 rounded-lg border border-[#eadde3] bg-white p-4 shadow-sm lg:grid-cols-[1fr_180px_220px_220px_auto]">
        <input
          name="q"
          defaultValue={filters.q}
          placeholder="Search title or message"
          className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 text-sm"
        />
        <select
          name="status"
          defaultValue={filters.status ?? ""}
          className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 text-sm"
        >
          <option value="">All statuses</option>
          {statusOptions.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
        <select
          name="audience"
          defaultValue={filters.audience ?? ""}
          className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 text-sm"
        >
          <option value="">All audiences</option>
          {audienceOptions.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
        <select
          name="type"
          defaultValue={filters.type ?? ""}
          className="focus-ring min-h-11 rounded-lg border border-[#ded2da] px-3 text-sm"
        >
          <option value="">All types</option>
          {notificationTypeOptions.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
        <Button type="submit" className="min-h-11 py-2">
          Filter
        </Button>
      </form>
      <AdminTable
        headers={[
          "Title",
          "Audience",
          "Requested",
          "Completed",
          "Recipients",
          "Status",
          "Created by",
          "Created date",
          "Scheduled date",
          "Actions",
        ]}
        empty="No admin notifications found."
        rows={history.map((item) => (
          <tr
            key={item.id}
            className="block rounded-lg border border-[#eadde3] p-4 md:table-row md:border-0 md:p-0"
          >
            <td className="px-4 py-3 font-semibold text-[#201925]">
              {item.title}
            </td>
            <td className="px-4 py-3 text-[#66616f]">
              {labelFor(audienceOptions, item.audience_type)}
            </td>
            <td className="px-4 py-3 text-[#66616f]">
              {(item.channels ?? []).join(", ")}
            </td>
            <td className="px-4 py-3 text-[#66616f]">
              In-app {item.in_app_success_count ?? 0}
              <br />
              Push eligible {item.push_eligible_device_count ?? 0}
              <br />
              Push accepted {item.push_success_count ?? 0}
              <br />
              Push failed {item.push_failure_count ?? 0}
              <br />
              Push skipped {item.push_skipped_count ?? 0}
            </td>
            <td className="px-4 py-3 text-[#66616f]">
              {item.recipient_count ?? 0}
            </td>
            <td className="px-4 py-3">
              <AdminStatus status={item.status} />
            </td>
            <td className="px-4 py-3 text-[#66616f]">
              {item.profiles?.email ?? item.created_by}
            </td>
            <td className="px-4 py-3 text-[#66616f]">
              {formatDate(item.created_at)}
            </td>
            <td className="px-4 py-3 text-[#66616f]">
              {formatDate(item.scheduled_at)}
            </td>
            <td className="px-4 py-3">
              <div className="flex flex-wrap gap-2 text-sm">
                <SafeLink href={`/admin/notifications?duplicate=${item.id}`}>
                  Duplicate
                </SafeLink>
                {item.status === "draft" ? (
                  <SafeLink href={`/admin/notifications?edit=${item.id}`}>
                    Edit draft
                  </SafeLink>
                ) : null}
                {item.status === "scheduled" ? (
                  <span className="font-semibold text-[#8a7c88]">
                    Cancel scheduled
                  </span>
                ) : null}
                {item.status === "failed" ? (
                  <span className="font-semibold text-[#8a7c88]">
                    Retry failed
                  </span>
                ) : null}
                <span className="font-semibold text-[#8a7c88]">View</span>
              </div>
            </td>
          </tr>
        ))}
      />
    </section>
  );
}

function SummaryItem({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs font-semibold uppercase tracking-[0.1em] text-[#8a7c88]">
        {label}
      </dt>
      <dd className="mt-1 text-[#201925]">{value || "Not provided"}</dd>
    </div>
  );
}

function labelFor(
  options: ReadonlyArray<{ value: string; label: string }>,
  value: string,
) {
  return options.find((option) => option.value === value)?.label ?? value;
}

function formatDate(value?: string | null) {
  if (!value) return "-";
  return new Date(value).toLocaleDateString();
}

const channelOptions = [
  { value: "in_app", label: "In-app notification" },
  { value: "push", label: "Push notification" },
  { value: "email", label: "Email" },
  { value: "whatsapp", label: "WhatsApp" },
] as const;

function createIdempotencyKey() {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto)
    return crypto.randomUUID();
  return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}
