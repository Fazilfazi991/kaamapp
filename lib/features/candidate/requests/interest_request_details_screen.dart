import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/privacy_badge.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../models/candidate_models.dart';

class InterestRequestDetailsScreen extends StatefulWidget {
  const InterestRequestDetailsScreen({super.key});

  @override
  State<InterestRequestDetailsScreen> createState() =>
      _InterestRequestDetailsScreenState();
}

class _InterestRequestDetailsScreenState
    extends State<InterestRequestDetailsScreen> {
  final repository = const InterestRepository();
  bool saving = false;

  Future<void> _respond(InterestRequest request, bool accepted) async {
    setState(() => saving = true);
    try {
      await repository.respondToInterest(
        requestId: request.id ?? '',
        accepted: accepted,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? 'Interest accepted. Match created.'
                : 'Interest declined.',
          ),
        ),
      );
      Navigator.of(
        context,
      ).pushNamed(accepted ? AppRoutes.matches : AppRoutes.requests);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not update this request. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request =
        ModalRoute.of(context)?.settings.arguments as InterestRequest?;
    if (request == null) {
      return const ScreenScaffold(
        title: 'Request Details',
        showBack: true,
        children: [Text('Request not found.', style: AppTextStyles.body)],
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
              Row(
                children: [
                  Expanded(
                    child: Text(request.company, style: AppTextStyles.title),
                  ),
                  StatusBadge(label: request.status),
                ],
              ),
              const SizedBox(height: 16),
              _Line('Industry', request.industry),
              _Line('Role', request.role),
              _Line('Salary', request.salary),
              _Line('Location', request.location),
              _Line('Working hours', request.hours),
              _Line('Accommodation', request.accommodation, optional: true),
              _Line('Transport', request.transport, optional: true),
              _Line('Visa Support', request.visaSupport, optional: true),
              if (request.message.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Message from employer', style: AppTextStyles.label),
                const SizedBox(height: 6),
                Text(request.message, style: AppTextStyles.body),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const PrivacyBadge(
          label: 'Your phone number is hidden until you accept.',
        ),
        const SizedBox(height: 24),
        if (request.status.toLowerCase() == 'pending') ...[
          PrimaryButton(
            label: saving ? 'Saving...' : 'Accept Interest',
            onPressed: saving ? null : () => _respond(request, true),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Decline',
            onPressed: saving ? null : () => _respond(request, false),
          ),
        ] else
          PrimaryButton(
            label: 'View Matches',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.matches),
          ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.optional = false});
  final String label;
  final String value;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final cleaned = value.trim();
    if (optional && cleaned.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: 3),
          Text(
            cleaned.isEmpty ? 'Not specified' : cleaned,
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}
