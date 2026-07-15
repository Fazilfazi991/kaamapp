import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../models/employer_models.dart';
import '../widgets/employer_widgets.dart';

class EmployerMatchUnlockedScreen extends StatelessWidget {
  const EmployerMatchUnlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final match = ModalRoute.of(context)?.settings.arguments as EmployerMatch?;
    return ScreenScaffold(
      title: 'Match Unlocked',
      children: [
        const Icon(Icons.handshake_rounded, color: AppColors.success, size: 72),
        const SizedBox(height: 18),
        const Text('Match Unlocked', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        Text(
          match?.chatEnabled == true
              ? 'The candidate accepted your interest request. You can now chat securely.'
              : 'The candidate accepted your interest request. Direct communication is unavailable until the candidate unlocks it.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 20),
        if (match != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(match.name, style: AppTextStyles.title),
                Text('${match.role} - ${match.location}',
                    style: AppTextStyles.body),
                Text('Match date: ${match.matchDate}',
                    style: AppTextStyles.muted),
              ],
            ),
          ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: match?.chatEnabled == true ? 'Start Chat' : 'Chat Unavailable',
          onPressed: match?.chatEnabled == true
              ? () => Navigator.of(context).pushNamed(
                    AppRoutes.employerPrivateChat,
                    arguments: match,
                  )
              : null,
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'View Matches',
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.employerMatches),
        ),
      ],
    );
  }
}

class EmployerMatchesScreen extends StatefulWidget {
  const EmployerMatchesScreen({super.key});

  @override
  State<EmployerMatchesScreen> createState() => _EmployerMatchesScreenState();
}

class _EmployerMatchesScreenState extends State<EmployerMatchesScreen> {
  final repository = const MatchRepository();
  late Future<List<EmployerMatch>> matchesFuture = repository.employerMatches();

  void _refresh() {
    setState(() => matchesFuture = repository.employerMatches());
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Active Matches',
      bottomNavigationBar: const EmployerBottomNav(currentIndex: 2),
      actions: [
        IconButton(
            icon: const Icon(Icons.refresh_rounded), onPressed: _refresh),
        IconButton(
          tooltip: 'Hiring pipeline',
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.employerPipeline),
          icon: const Icon(Icons.view_kanban_outlined),
        ),
      ],
      children: [
        FutureBuilder<List<EmployerMatch>>(
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
            final matches = snapshot.data ?? const <EmployerMatch>[];
            if (matches.isEmpty) {
              return const EmptyState(
                icon: Icons.handshake_outlined,
                title: 'No active matches',
                message: 'Accepted candidate requests will appear here.',
              );
            }
            return Column(
              children: [
                for (final match in matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EmployerMatchCard(match: match),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class HiringPipelineScreen extends StatefulWidget {
  const HiringPipelineScreen({super.key});

  @override
  State<HiringPipelineScreen> createState() => _HiringPipelineScreenState();
}

class _HiringPipelineScreenState extends State<HiringPipelineScreen> {
  int stage = 0;
  final stages = const [
    'New Matches',
    'Interviewing',
    'Offered',
    'Hired',
    'Closed'
  ];

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Hiring Pipeline',
      showBack: true,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            segments: List.generate(
                stages.length,
                (index) =>
                    ButtonSegment(value: index, label: Text(stages[index]))),
            selected: {stage},
            onSelectionChanged: (value) => setState(() => stage = value.first),
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(stages[stage], style: AppTextStyles.title)),
                  const StatusBadge(
                      label: 'Local stage', color: AppColors.accentPurple),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                  'Pipeline stage editing is local until pipeline columns are added to matches.',
                  style: AppTextStyles.body),
              const SizedBox(height: 14),
              SecondaryButton(
                  label: 'Move Stage',
                  onPressed: () =>
                      setState(() => stage = (stage + 1) % stages.length)),
            ],
          ),
        ),
      ],
    );
  }
}
