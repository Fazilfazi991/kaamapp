import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/candidate_widgets.dart';
import '../../../core/widgets/chat_conversation_view.dart';
import '../../../core/widgets/kaam_app_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../models/candidate_models.dart';

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({super.key});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final repository = const ChatRepository();

  @override
  Widget build(BuildContext context) {
    final match = ModalRoute.of(context)?.settings.arguments as MatchItem?;
    final matchId = match?.id ?? '';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: KaamAppBar(
        title: match?.company ?? 'Private Chat',
        showBack: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusBadge(
                label: 'Matched',
                icon: Icons.lock_open_rounded,
              ),
              const SizedBox(height: 6),
              Text(
                match?.role ?? 'Chat opens only after match',
                style: AppTextStyles.muted,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ChatConversationView(
                  gateway: repository,
                  matchId: matchId,
                  senderId: currentUserId,
                  composerHint: 'Type a message...',
                  bubbleBuilder: (context, row) => ChatBubble(
                    text: row['body'] as String? ?? '',
                    isMe: row['sender_id'] == currentUserId,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
