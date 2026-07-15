import 'package:flutter/material.dart';

import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/candidate_widgets.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../models/candidate_models.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final repository = const MatchRepository();
  late Future<List<MatchItem>> matchesFuture = repository.candidateMatches();

  void _refresh() {
    setState(() => matchesFuture = repository.candidateMatches());
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'My Matches',
      bottomNavigationBar: const KaamBottomNav(currentIndex: 2),
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
                title: 'Could not load matches',
                message: snapshot.error.toString(),
                action: PrimaryButton(label: 'Retry', onPressed: _refresh),
              );
            }
            final matches = snapshot.data ?? const <MatchItem>[];
            if (matches.isEmpty) {
              return const EmptyState(
                icon: Icons.handshake_outlined,
                title: 'No accepted matches yet',
                message: 'Accept an employer interest to unlock chat.',
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
