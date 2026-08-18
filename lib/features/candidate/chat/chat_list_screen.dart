import 'package:flutter/material.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../models/candidate_models.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final repository = const MatchRepository();
  late Future<List<CandidateConversation>> conversationsFuture =
      repository.candidateConversations();

  void _refresh() {
    setState(() => conversationsFuture = repository.candidateConversations());
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Messages',
      bottomNavigationBar: const KaamBottomNav(currentIndex: 3),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _refresh,
        ),
      ],
      body: FutureBuilder<List<CandidateConversation>>(
        future: conversationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load chats',
              message: snapshot.error.toString(),
              action: PrimaryButton(label: 'Retry', onPressed: _refresh),
            );
          }
          final conversations =
              snapshot.data ?? const <CandidateConversation>[];
          if (conversations.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No messages yet',
              message: 'Chat unlocks after you accept an employer request.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return Padding(
                key: ValueKey(conversation.match.id),
                padding: const EdgeInsets.only(bottom: 12),
                child: _ConversationTile(conversation: conversation),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final CandidateConversation conversation;

  @override
  Widget build(BuildContext context) {
    final match = conversation.match;
    final preview = conversation.hasMessages
        ? conversation.lastMessage
        : 'Start a conversation';
    final unread = conversation.unreadCount;
    final initials = match.company
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Semantics(
      button: true,
      label: 'Conversation with ${match.company}',
      child: AppCard(
        onTap: () => Navigator.of(context).pushNamed(
          '/candidate/chat/private',
          arguments: match,
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryPink.withValues(alpha: .16),
              child: Text(initials.isEmpty ? '?' : initials),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.company, style: AppTextStyles.title),
                  const SizedBox(height: 2),
                  Text(match.role, style: AppTextStyles.muted),
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        unread > 0 ? AppTextStyles.body : AppTextStyles.muted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (conversation.lastMessageAt != null)
                  Text(_timestamp(conversation.lastMessageAt!),
                      style: AppTextStyles.muted),
                if (unread > 0) ...[
                  const SizedBox(height: 8),
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.primaryPink,
                    child:
                        Text('$unread', style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    if (DateUtils.isSameDay(local, now)) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }
    return '${local.day}/${local.month}/${local.year}';
  }
}
