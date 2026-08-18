import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/chat_conversation_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/kaam_app_bar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/private_profile_photo_avatar.dart';
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
      bottomNavigationBar: const EmployerBottomNav(currentIndex: 3),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _refresh,
        ),
      ],
      body: FutureBuilder<List<EmployerMatch>>(
        future: matchesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load chats',
              message: 'Please try again.',
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
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: matches.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: AppTextField(
                    label: 'Search conversations',
                    hint: 'Candidate ID, role, message',
                  ),
                );
              }
              final match = matches[index - 1];
              return Padding(
                key: ValueKey(match.matchId),
                padding: const EdgeInsets.only(bottom: 12),
                child: EmployerChatCard(match: match),
              );
            },
          );
        },
      ),
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
  final repository = const ChatRepository();

  @override
  Widget build(BuildContext context) {
    final match = ModalRoute.of(context)?.settings.arguments as EmployerMatch?;
    final matchId = match?.matchId ?? '';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: KaamAppBar(title: match?.name ?? 'Private Chat', showBack: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    PrivateProfilePhotoAvatar(
                      path: match?.profilePhotoUrl ?? '',
                      candidateId: match?.candidateProfileId,
                      initials: profileInitials(
                        match?.name ?? 'Candidate',
                        fallback: 'C',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match?.name ?? 'Candidate',
                            style: AppTextStyles.label,
                          ),
                          Text(
                            '${match?.role ?? ''} ${match?.location ?? ''}',
                            style: AppTextStyles.muted,
                          ),
                        ],
                      ),
                    ),
                    const StatusBadge(
                      label: 'Matched',
                      color: AppColors.success,
                      icon: Icons.lock_open_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ChatConversationView(
                  gateway: repository,
                  matchId: matchId,
                  senderId: currentUserId,
                  composerHint: 'Write your message',
                  bubbleBuilder: (context, row) => EmployerChatBubble(
                    isEmployer: row['sender_id'] == currentUserId,
                    text: row['body'] as String? ?? '',
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
          label: 'Interview location',
          hint: 'Office or video link',
        ),
        const SizedBox(height: 12),
        const AppTextField(
          label: 'Notes for candidate',
          hint: 'Interview details',
          maxLines: 4,
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Interview scheduling disabled',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
