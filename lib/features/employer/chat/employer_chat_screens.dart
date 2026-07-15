import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../models/employer_models.dart';
import '../widgets/employer_widgets.dart';

class EmployerChatListScreen extends StatefulWidget {
  const EmployerChatListScreen({super.key});

  @override
  State<EmployerChatListScreen> createState() => _EmployerChatListScreenState();
}

class _EmployerChatListScreenState extends State<EmployerChatListScreen> {
  final repository = const MatchRepository();
  late Future<List<EmployerMatch>> matchesFuture = repository.employerMatches();

  void _refresh() {
    setState(() => matchesFuture = repository.employerMatches());
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Messages',
      bottomNavigationBar: const EmployerBottomNav(currentIndex: 2),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _refresh)
      ],
      children: [
        const AppTextField(
            label: 'Search conversations', hint: 'Candidate ID, role, message'),
        const SizedBox(height: 16),
        FutureBuilder<List<EmployerMatch>>(
          future: matchesFuture,
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
            final matches = snapshot.data ?? const <EmployerMatch>[];
            if (matches.isEmpty) {
              return const EmptyState(
                icon: Icons.chat_bubble_outline,
                title: 'No chats yet',
                message:
                    'Chats appear after candidates accept interest requests.',
              );
            }
            return Column(
              children: [
                for (final match in matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EmployerChatCard(match: match),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class EmployerPrivateChatScreen extends StatefulWidget {
  const EmployerPrivateChatScreen({super.key});

  @override
  State<EmployerPrivateChatScreen> createState() =>
      _EmployerPrivateChatScreenState();
}

class _EmployerPrivateChatScreenState extends State<EmployerPrivateChatScreen> {
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
    final match = ModalRoute.of(context)?.settings.arguments as EmployerMatch?;
    final matchId = match?.matchId ?? '';
    final chatEnabled = match?.chatEnabled ?? false;
    return ScreenScaffold(
      title: match?.name ?? 'Private Chat',
      showBack: true,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.elevatedCard,
                child: Icon(Icons.person_outline_rounded,
                    color: AppColors.primaryPink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match?.candidateId ?? 'Open from an accepted match',
                        style: AppTextStyles.label),
                    Text('${match?.role ?? ''} ${match?.location ?? ''}',
                        style: AppTextStyles.muted),
                  ],
                ),
              ),
              const StatusBadge(
                  label: 'Matched',
                  color: AppColors.success,
                  icon: Icons.lock_open_rounded),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (!chatEnabled)
          const Text(
            'Contact details unavailable. The candidate has not unlocked direct communication.',
            style: AppTextStyles.body,
          )
        else if (matchId.isEmpty)
          const Text('Missing match id. Open chat from matches.',
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
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;
              if (rows.isEmpty) {
                return const Text('No messages yet.',
                    style: AppTextStyles.muted);
              }
              return Column(
                children: [
                  for (final row in rows)
                    EmployerChatBubble(
                      isEmployer: row['sender_id'] == currentUserId,
                      text: row['body'] as String? ?? '',
                    ),
                ],
              );
            },
          ),
        if (chatEnabled) ...[
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Write your message',
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

class EmployerScheduleInterviewScreen extends StatelessWidget {
  const EmployerScheduleInterviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Schedule Interview',
      showBack: true,
      children: [
        const AppTextField(label: 'Interview date', hint: 'Jul 12, 2026'),
        const SizedBox(height: 12),
        const AppTextField(label: 'Interview time', hint: '10:30 AM'),
        const SizedBox(height: 12),
        const AppTextField(
            label: 'Interview location', hint: 'Office or video link'),
        const SizedBox(height: 12),
        const AppTextField(
            label: 'Notes for candidate',
            hint: 'Interview details',
            maxLines: 4),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Interview scheduling disabled',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
