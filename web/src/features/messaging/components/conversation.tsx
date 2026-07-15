"use client";

import { useRef } from "react";
import { Button } from "@/components/ui/button";
import { sendChatMessage } from "@/features/messaging/server/actions";
import type { ChatMessageRow, ConversationAccess } from "@/features/messaging/types";

export function ConversationView({
  access,
  messages,
}: {
  access: ConversationAccess;
  messages: ChatMessageRow[];
}) {
  const formRef = useRef<HTMLFormElement>(null);
  return (
    <section className="rounded-lg border border-[#eadde3] bg-white p-5 shadow-sm">
      <div className="border-b border-[#eadde3] pb-4">
        <h2 className="text-lg font-semibold text-[#201925]">{access.title}</h2>
        <p className="mt-1 text-sm text-[#66616f]">{access.subtitle || "Matched conversation"}</p>
      </div>
      <div className="mt-5 grid max-h-[560px] gap-3 overflow-y-auto pr-1">
        {messages.length ? (
          messages.map((message) => {
            const own = message.sender_id === access.userId;
            return (
              <div key={message.id} className={`flex ${own ? "justify-end" : "justify-start"}`}>
                <div className={`max-w-[80%] rounded-lg px-4 py-3 text-sm ${own ? "bg-[#e53670] text-white" : "bg-[#f7f2f5] text-[#201925]"}`}>
                  <p className="whitespace-pre-wrap break-words">{message.body}</p>
                  <p className={`mt-2 text-xs ${own ? "text-white/75" : "text-[#66616f]"}`}>
                    {new Date(message.created_at).toLocaleString()}
                  </p>
                </div>
              </div>
            );
          })
        ) : (
          <p className="text-sm text-[#66616f]">No messages yet.</p>
        )}
      </div>
      {access.chatEnabled ? (
        <form ref={formRef} action={sendChatMessage} className="mt-5 grid gap-3">
          <input type="hidden" name="matchId" value={access.matchId} />
          <label className="sr-only" htmlFor="body">Message</label>
          <textarea
            id="body"
            name="body"
            rows={3}
            maxLength={2000}
            required
            className="focus-ring w-full rounded-lg border border-[#dfd2d9] bg-white px-4 py-3 text-base text-[#201925] shadow-sm"
            placeholder="Write your message"
            onKeyDown={(event) => {
              if (event.key === "Enter" && !event.shiftKey) {
                event.preventDefault();
                formRef.current?.requestSubmit();
              }
            }}
          />
          <div className="flex justify-end">
            <Button type="submit">Send</Button>
          </div>
        </form>
      ) : (
        <p className="mt-5 rounded-lg bg-[#fff4d6] p-4 text-sm text-[#7a5610]">
          Messaging is unavailable until the existing match chat rule allows it.
        </p>
      )}
    </section>
  );
}
