import { ButtonLink } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import type { ConversationSummary } from "@/features/messaging/types";

export function MessageInbox({ conversations }: { conversations: ConversationSummary[] }) {
  return (
    <div className="grid gap-4">
      {conversations.map((conversation) => (
        <article key={conversation.matchId} className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 className="text-lg font-semibold text-[#201925]">{conversation.title}</h2>
              <p className="mt-1 text-sm text-[#66616f]">{conversation.subtitle || "Matched conversation"}</p>
            </div>
            <StatusBadge tone={conversation.chatEnabled ? "success" : "warning"}>
              {conversation.chatEnabled ? "Open" : "Locked"}
            </StatusBadge>
          </div>
          <p className="mt-4 line-clamp-2 text-sm leading-6 text-[#3b3340]">{conversation.lastMessage}</p>
          <div className="mt-5 flex flex-wrap items-center gap-3">
            <ButtonLink href={conversation.href} variant="secondary">Open conversation</ButtonLink>
            {conversation.unreadCount > 0 ? (
              <span className="rounded-full bg-[#fff4d6] px-3 py-1 text-xs font-semibold text-[#7a5610]">
                {conversation.unreadCount} unread
              </span>
            ) : null}
          </div>
        </article>
      ))}
    </div>
  );
}
