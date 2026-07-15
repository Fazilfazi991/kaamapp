import 'package:flutter/material.dart';

import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/candidate_widgets.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../models/candidate_models.dart';

class InterestRequestsScreen extends StatefulWidget {
  const InterestRequestsScreen({super.key});

  @override
  State<InterestRequestsScreen> createState() => _InterestRequestsScreenState();
}

class _InterestRequestsScreenState extends State<InterestRequestsScreen> {
  final repository = const InterestRepository();
  late Future<List<InterestRequest>> requestsFuture = repository.candidateRequests();

  void _refresh() {
    setState(() => requestsFuture = repository.candidateRequests());
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Interest Requests',
      bottomNavigationBar: const KaamBottomNav(currentIndex: 1),
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _refresh)],
      children: [
        FutureBuilder<List<InterestRequest>>(
          future: requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load requests',
                message: snapshot.error.toString(),
                action: PrimaryButton(label: 'Retry', onPressed: _refresh),
              );
            }
            final requests = snapshot.data ?? const <InterestRequest>[];
            if (requests.isEmpty) {
              return const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No interest requests yet',
                message: 'Employer requests sent to you will appear here.',
              );
            }
            return Column(
              children: [
                for (final request in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InterestRequestCard(request: request),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
