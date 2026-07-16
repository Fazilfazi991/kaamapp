export const maxMessageLength = 2000;

export function normalizeMessageBody(value: string) {
  return value.replace(/\r\n/g, "\n").trim();
}

export function validateMessageBody(value: string) {
  const normalized = normalizeMessageBody(value);
  if (!normalized) return { ok: false as const, error: "Message cannot be empty." };
  if (normalized.length > maxMessageLength) {
    return { ok: false as const, error: `Message must be ${maxMessageLength} characters or fewer.` };
  }
  return { ok: true as const, value: normalized };
}

export function dedupeMessages<T extends { id: string }>(messages: T[]) {
  return [...new Map(messages.map((message) => [message.id, message])).values()];
}

export function shouldAcceptRealtimeEvent(eventMatchId: string, activeMatchId: string) {
  return eventMatchId === activeMatchId;
}
