import 'package:flutter/material.dart';

import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/candidate_widgets.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../models/candidate_models.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final repository = const MatchRepository();
  late Future<List<MatchItem>> matchesFuture = repository.candidateMatches();

  void _refresh() {
    setState(() => matchesFuture = repository.candidateMatches());
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Messages',
      bottomNavigationBar: const KaamBottomNav(currentIndex: 3),
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _refresh)],
      children: [
        FutureBuilder<List<MatchItem>>(
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
            final matches = snapshot.data ?? const <MatchItem>[];
            if (matches.isEmpty) {
              return const EmptyState(
                icon: Icons.chat_bubble_outline,
                title: 'No messages yet',
                message: 'Chat unlocks after you accept an employer request.',
              );
            }
            return Column(
              children: [
                for (final match in matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MatchCard(match: match),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
