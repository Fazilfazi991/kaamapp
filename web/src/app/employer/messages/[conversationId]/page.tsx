import { notFound } from "next/navigation";
import { PageTitle } from "@/components/layout/page-title";
import { ConversationView } from "@/features/messaging/components/conversation";
import { loadConversation } from "@/features/messaging/server/data";

export default async function EmployerConversationPage({
  params,
}: {
  params: Promise<{ conversationId: string }>;
}) {
  const { conversationId } = await params;
  const conversation = await loadConversation(conversationId);
  if (!conversation || conversation.access.role !== "employer") notFound();
  return (
    <div className="grid gap-6">
      <PageTitle title="Conversation" description="Messages are available only for authorized matched users." />
      <ConversationView access={conversation.access} messages={conversation.messages} />
    </div>
  );
}
