import { ButtonLink } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import type { ConversationSummary } from "@/features/messaging/types";

export function MessageInbox({ conversations }: { conversations: ConversationSummary[] }) {
  return (
    <div className="grid min-w-0 gap-4">
      {conversations.map((conversation) => (
        <article key={conversation.matchId} className="min-w-0 rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="min-w-0">
              <h2 className="break-words text-lg font-semibold text-[#201925] [overflow-wrap:anywhere]">{conversation.title}</h2>
              <p className="mt-1 break-words text-sm text-[#66616f] [overflow-wrap:anywhere]">{conversation.subtitle || "Matched conversation"}</p>
            </div>
            <StatusBadge tone={conversation.chatEnabled ? "success" : "warning"}>
              {conversation.chatEnabled ? "Open" : "Locked"}
            </StatusBadge>
          </div>
          <p className="mt-4 line-clamp-2 break-words text-sm leading-6 text-[#3b3340] [overflow-wrap:anywhere]">{conversation.lastMessage}</p>
          {conversation.lastMessageAt ? (
            <time className="mt-1 block text-xs text-[#716674]" dateTime={conversation.lastMessageAt}>
              {new Date(conversation.lastMessageAt).toLocaleString()}
            </time>
          ) : null}
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
