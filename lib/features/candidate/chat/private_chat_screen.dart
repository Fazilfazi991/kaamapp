import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/candidate_widgets.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../models/candidate_models.dart';

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({super.key});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final controller = TextEditingController();
  final repository = const ChatRepository();
  bool sending = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _send(String matchId) async {
    setState(() => sending = true);
    try {
      await repository.sendMessage(matchId: matchId, body: controller.text);
      controller.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $error')),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = ModalRoute.of(context)?.settings.arguments as MatchItem?;
    final matchId = match?.id ?? '';
    final chatEnabled = match?.chatEnabled ?? false;
    return ScreenScaffold(
      title: match?.company ?? 'Private Chat',
      showBack: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      children: [
        const StatusBadge(label: 'Matched', icon: Icons.lock_open_rounded),
        const SizedBox(height: 6),
        Text(match?.role ?? 'Chat opens only after match',
            style: AppTextStyles.muted),
        const SizedBox(height: 22),
        if (!chatEnabled)
          const Text(
            'Upgrade Candidate Membership to chat with matched employers and reveal your contact details.',
            style: AppTextStyles.body,
          )
        else if (matchId.isEmpty)
          const Text('Missing match id. Open chat from a saved match.',
              style: AppTextStyles.body)
        else
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: repository.messages(matchId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Could not load messages: ${snapshot.error}',
                    style: AppTextStyles.body);
              }
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const Text('No messages yet.',
                    style: AppTextStyles.muted);
              }
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;
              return Column(
                children: [
                  for (final row in rows) ...[
                    ChatBubble(
                      text: row['body'] as String? ?? '',
                      isMe: row['sender_id'] == currentUserId,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        if (chatEnabled) ...[
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Type a message...',
              suffixIcon: IconButton(
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded,
                        color: AppColors.primaryPink),
                onPressed:
                    sending || matchId.isEmpty ? null : () => _send(matchId),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
