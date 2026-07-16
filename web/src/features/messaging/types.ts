import type { UserRole } from "@/types/domain";

export type ChatMessageRow = {
  id: string;
  match_id: string;
  sender_id: string;
  body: string;
  is_read: boolean | null;
  created_at: string;
};

export type ConversationSummary = {
  matchId: string;
  title: string;
  subtitle: string;
  href: string;
  chatEnabled: boolean;
  lastMessage: string;
  lastMessageAt: string | null;
  unreadCount: number;
};

export type ConversationAccess = {
  userId: string;
  role: UserRole;
  matchId: string;
  chatEnabled: boolean;
  title: string;
  subtitle: string;
};
