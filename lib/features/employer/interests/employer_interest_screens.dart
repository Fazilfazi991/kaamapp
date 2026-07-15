import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../models/employer_models.dart';
import '../widgets/employer_widgets.dart';

class SendInterestScreen extends StatefulWidget {
  const SendInterestScreen({super.key});

  @override
  State<SendInterestScreen> createState() => _SendInterestScreenState();
}

class _SendInterestScreenState extends State<SendInterestScreen> {
  final jobTitleController = TextEditingController();
  final salaryController = TextEditingController();
  final locationController = TextEditingController();
  final hoursController = TextEditingController();
  final messageController = TextEditingController();
  final repository = const InterestRepository();
  bool accommodation = true;
  bool transport = true;
  bool visa = false;
  bool sending = false;

  @override
  void dispose() {
    jobTitleController.dispose();
    salaryController.dispose();
    locationController.dispose();
    hoursController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> _send(EmployerCandidate candidate) async {
    setState(() => sending = true);
    try {
      await repository.sendInterest(
        candidateId: candidate.candidateProfileId ?? '',
        jobTitle: jobTitleController.text,
        salaryRange: salaryController.text,
        location: locationController.text,
        workingHours: hoursController.text,
        message: messageController.text,
        accommodationProvided: accommodation,
        transportProvided: transport,
        visaSupport: visa,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interest request sent.')),
      );
      Navigator.of(context).pushNamed(AppRoutes.employerSentRequests);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send interest: $error')),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final candidate = args is EmployerCandidate ? args : null;
    if (candidate == null) {
      return const ScreenScaffold(
        title: 'Send Interest Request',
        showBack: true,
        children: [Text('Open this screen from candidate search.', style: AppTextStyles.body)],
      );
    }
    return ScreenScaffold(
      title: 'Send Interest Request',
      showBack: true,
      children: [
        CandidateMiniProfileCard(candidate: candidate, showActions: false),
        const SizedBox(height: 16),
        AppTextField(controller: jobTitleController, label: 'Job title', hint: 'Cleaning Team Lead'),
        const SizedBox(height: 12),
        AppTextField(controller: salaryController, label: 'Salary range', hint: 'AED 2,200 - AED 2,800'),
        const SizedBox(height: 12),
        AppTextField(controller: locationController, label: 'Work location', hint: 'Dubai'),
        const SizedBox(height: 12),
        AppTextField(controller: hoursController, label: 'Working hours', hint: '9 hours with weekly off'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: accommodation,
          onChanged: (value) => setState(() => accommodation = value),
          title: const Text('Accommodation provided', style: AppTextStyles.body),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: transport,
          onChanged: (value) => setState(() => transport = value),
          title: const Text('Transport provided', style: AppTextStyles.body),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: visa,
          onChanged: (value) => setState(() => visa = value),
          title: const Text('Visa support', style: AppTextStyles.body),
        ),
        AppTextField(
          controller: messageController,
          label: 'Message to candidate',
          hint: 'Write a short intro about the role and why you want to connect.',
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        const Text('The candidate will review your request. Chat opens only if they accept.', style: AppTextStyles.muted),
        const SizedBox(height: 20),
        PrimaryButton(
          label: sending ? 'Sending...' : 'Send Interest',
          onPressed: sending ? null : () => _send(candidate),
        ),
      ],
    );
  }
}

class InterestSentConfirmationScreen extends StatelessWidget {
  const InterestSentConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Interest Sent',
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 72),
        const SizedBox(height: 18),
        Text('Interest Sent', style: AppTextStyles.headline.copyWith(color: AppColors.white)),
        const SizedBox(height: 8),
        const Text('The candidate has been notified.', style: AppTextStyles.body),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'View Sent Interests',
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.employerSentRequests),
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Search More Candidates',
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.employerCandidateSearch),
        ),
      ],
    );
  }
}

class SentInterestRequestsScreen extends StatefulWidget {
  const SentInterestRequestsScreen({super.key});

  @override
  State<SentInterestRequestsScreen> createState() => _SentInterestRequestsScreenState();
}

class _SentInterestRequestsScreenState extends State<SentInterestRequestsScreen> {
  final repository = const InterestRepository();
  late Future<List<EmployerInterestRequest>> requestsFuture = repository.employerRequests();

  void _refresh() {
    setState(() => requestsFuture = repository.employerRequests());
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Interest Requests',
      bottomNavigationBar: const EmployerBottomNav(currentIndex: 3),
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _refresh)],
      children: [
        FutureBuilder<List<EmployerInterestRequest>>(
          future: requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load interests',
                message: snapshot.error.toString(),
                action: PrimaryButton(label: 'Retry', onPressed: _refresh),
              );
            }
            final requests = snapshot.data ?? const <EmployerInterestRequest>[];
            if (requests.isEmpty) {
              return EmptyState(
                icon: Icons.outbox_outlined,
                title: 'No sent requests yet',
                message: 'Send interest from candidate search.',
                action: PrimaryButton(
                  label: 'Search Candidates',
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.employerCandidateSearch),
                ),
              );
            }
            return Column(
              children: [
                for (final request in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SentInterestRequestCard(request: request),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class EmployerInterestRequestDetailsScreen extends StatelessWidget {
  const EmployerInterestRequestDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final request = ModalRoute.of(context)?.settings.arguments as EmployerInterestRequest?;
    if (request == null) {
      return const ScreenScaffold(
        title: 'Request Details',
        showBack: true,
        children: [Text('Open this screen from sent interests.', style: AppTextStyles.body)],
      );
    }
    return ScreenScaffold(
      title: 'Request Details',
      showBack: true,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.candidateId, style: AppTextStyles.headline),
              const SizedBox(height: 8),
              Text('${request.role} - ${request.location}', style: AppTextStyles.body),
              Text('Job sent: ${request.jobTitle}', style: AppTextStyles.body),
              Text('Salary: ${request.salary}', style: AppTextStyles.body),
              Text('Working hours: ${request.workingHours}', style: AppTextStyles.body),
              const SizedBox(height: 12),
              Text(request.message, style: AppTextStyles.body),
            ],
          ),
        ),
        const SizedBox(height: 18),
        StatusBadge(label: request.status, color: AppColors.warning),
      ],
    );
  }
}
