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
  late Future<List<InterestRequest>> requestsFuture =
      repository.candidateRequests();

  void _refresh() {
    setState(() => requestsFuture = repository.candidateRequests());
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Interest Requests',
      bottomNavigationBar: const KaamBottomNav(currentIndex: 1),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _refresh,
        ),
      ],
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
                message: 'Please try again.',
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
            final pending = _withStatus(requests, 'pending');
            final accepted = _withStatus(requests, 'accepted');
            final declined = _withStatus(requests, 'rejected');
            return DefaultTabController(
              length: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Employers waiting for your response',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    tabs: [
                      Tab(text: 'Pending (${pending.length})'),
                      Tab(text: 'Accepted (${accepted.length})'),
                      Tab(text: 'Declined (${declined.length})'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 560,
                    child: TabBarView(
                      children: [
                        _RequestList(
                          requests: pending,
                          emptyTitle: 'No pending requests',
                          emptyMessage:
                              'New employer requests will appear here.',
                        ),
                        _RequestList(
                          requests: accepted,
                          emptyTitle: 'No accepted requests',
                          emptyMessage:
                              'Accepted requests are also available in Matches.',
                        ),
                        _RequestList(
                          requests: declined,
                          emptyTitle: 'No declined requests',
                          emptyMessage:
                              'Declined requests stay here as history.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

List<InterestRequest> _withStatus(
        List<InterestRequest> requests, String status) =>
    requests
        .where((request) => request.status.toLowerCase() == status)
        .toList();

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.requests,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<InterestRequest> requests;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: emptyTitle,
        message: emptyMessage,
      );
    }
    return ListView.separated(
      itemCount: requests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          InterestRequestCard(request: requests[index]),
    );
  }
}
