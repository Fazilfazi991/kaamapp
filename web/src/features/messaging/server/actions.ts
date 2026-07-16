"use server";

import { revalidatePath } from "next/cache";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { routes } from "@/config/routes";
import { resolveConversationAccess } from "./data";
import { validateMessageBody } from "@/features/messaging/validation";

function safeError(message: string): never {
  throw new Error(message);
}

export async function sendChatMessage(formData: FormData) {
  const matchId = String(formData.get("matchId") ?? "");
  const body = String(formData.get("body") ?? "");
  if (!matchId) safeError("Conversation is missing.");
  const access = await resolveConversationAccess(matchId);
  if (!access) safeError("Conversation was not found.");
  if (!access.chatEnabled) safeError("Messaging is not available for this match.");
  const validation = validateMessageBody(body);
  if (!validation.ok) safeError(validation.error);
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.from("chat_messages").insert({
    match_id: matchId,
    sender_id: access.userId,
    body: validation.value,
  });
  if (error) safeError("Could not send message.");
  revalidatePath(access.role === "candidate" ? routes.candidateMessages : routes.employerMessages);
  revalidatePath(access.role === "candidate" ? `/candidate/messages/${matchId}` : `/employer/messages/${matchId}`);
}
