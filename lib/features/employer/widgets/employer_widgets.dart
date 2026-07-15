import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/skill_chip.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/employer_models.dart';
import '../../supabase_backend/kaam_backend.dart';

class EmployerBottomNav extends StatelessWidget {
  const EmployerBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _routes = [
    AppRoutes.employerDashboard,
    AppRoutes.employerHiringRequirements,
    AppRoutes.employerMatches,
    AppRoutes.employerSentRequests,
    AppRoutes.employerCompanyProfile,
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (index == currentIndex) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil(_routes[index], (route) => route.isFirst);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(
            icon: Icon(Icons.work_history_outlined), label: 'Hiring'),
        NavigationDestination(
          icon: Icon(Icons.handshake_outlined, size: 30),
          selectedIcon: Icon(Icons.handshake_rounded, size: 34),
          label: 'Matches',
        ),
        NavigationDestination(
            icon: Icon(Icons.outbox_rounded), label: 'Interests'),
        NavigationDestination(
            icon: Icon(Icons.business_outlined), label: 'Company'),
      ],
    );
  }
}

class EmployerStatCard extends StatelessWidget {
  const EmployerStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primaryPink,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 14),
          Text(value, style: AppTextStyles.headline),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.muted),
        ],
      ),
    );
  }
}

class EmployerQuickActionCard extends StatelessWidget {
  const EmployerQuickActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPink),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.muted),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
        ],
      ),
    );
  }
}

class FilterChipGroup extends StatefulWidget {
  const FilterChipGroup({super.key, required this.options});

  final List<String> options;

  @override
  State<FilterChipGroup> createState() => _FilterChipGroupState();
}

class _FilterChipGroupState extends State<FilterChipGroup> {
  final Set<String> selected = {};

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.options.map((option) {
        final active = selected.contains(option);
        return FilterChip(
          label: Text(option),
          selected: active,
          onSelected: (_) => setState(() {
            active ? selected.remove(option) : selected.add(option);
          }),
        );
      }).toList(),
    );
  }
}

class CandidateMiniProfileCard extends StatefulWidget {
  const CandidateMiniProfileCard({
    super.key,
    required this.candidate,
    this.showActions = true,
  });

  final EmployerCandidate candidate;
  final bool showActions;

  @override
  State<CandidateMiniProfileCard> createState() =>
      _CandidateMiniProfileCardState();
}

class _CandidateMiniProfileCardState extends State<CandidateMiniProfileCard> {
  late bool saved = widget.candidate.isSaved;
  final repository = const EmployerRepository();

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CandidateAvatar(candidate: candidate),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(candidate.displayName, style: AppTextStyles.title),
                    const SizedBox(height: 4),
                    Text(candidate.role,
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.white)),
                  ],
                ),
              ),
              IconButton(
                tooltip: saved ? 'Saved' : 'Save candidate',
                onPressed: () async {
                  try {
                    await repository
                        .saveCandidate(candidate.candidateProfileId ?? '');
                    if (!mounted) return;
                    setState(() => saved = true);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Candidate saved.')),
                    );
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                          content: Text('Could not save candidate: $error')),
                    );
                  }
                },
                icon: Icon(saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded),
                color: saved ? AppColors.primaryPink : AppColors.secondaryText,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${candidate.experience} • ${candidate.location}',
              style: AppTextStyles.muted),
          Text(
              'Expected ${candidate.expectedSalary} • ${candidate.availability}',
              style: AppTextStyles.muted),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: candidate.skills
                .take(3)
                .map((skill) => SkillChip(label: skill))
                .toList(),
          ),
          const SizedBox(height: 12),
          const Text('Contact details unlock only after mutual approval.',
              style: AppTextStyles.muted),
          if (widget.showActions) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'View Profile',
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRoutes.employerCandidateProfile,
                      arguments: candidate,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: 'Send Interest',
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRoutes.employerSendInterest,
                      arguments: candidate,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CandidateAvatar extends StatelessWidget {
  const _CandidateAvatar({required this.candidate});

  final EmployerCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final initials = candidate.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    Widget fallback() => Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.elevatedCard,
            shape: BoxShape.circle,
          ),
          child: Text(
            initials.isEmpty ? 'C' : initials,
            style: AppTextStyles.label.copyWith(color: AppColors.primaryPink),
          ),
        );
    final url = candidate.profilePhotoUrl?.trim() ?? '';
    if (url.isEmpty) return fallback();
    return ClipOval(
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}

class CandidatePrivacyNoticeCard extends StatelessWidget {
  const CandidatePrivacyNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.primaryPink.withValues(alpha: 0.09),
      borderColor: AppColors.primaryPink.withValues(alpha: 0.35),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.primaryPink),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Private details hidden. Phone number, email, and documents unlock only after match or candidate permission.',
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}

class SentInterestRequestCard extends StatelessWidget {
  const SentInterestRequestCard({super.key, required this.request});

  final EmployerInterestRequest request;

  @override
  Widget build(BuildContext context) {
    final status = request.status.toLowerCase();
    final color = status == 'accepted'
        ? AppColors.success
        : status == 'rejected'
            ? AppColors.error
            : AppColors.warning;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(request.candidateId, style: AppTextStyles.title)),
              StatusBadge(label: request.status, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(request.jobTitle,
              style: AppTextStyles.body.copyWith(color: AppColors.white)),
          Text('${request.salary} • ${request.location}',
              style: AppTextStyles.muted),
          const SizedBox(height: 8),
          Text(request.message, style: AppTextStyles.body),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'View Details',
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.employerRequestDetails,
                    arguments: request,
                  ),
                ),
              ),
              if (status == 'pending') ...[
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    label: 'Cancel',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Cancel request?'),
                        content: const Text(
                            'This interest request will be withdrawn.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Keep')),
                          TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel Request')),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class EmployerMatchCard extends StatelessWidget {
  const EmployerMatchCard({super.key, required this.match});

  final EmployerMatch match;

  Future<void> _launchContact(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this contact action.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phoneDigits = match.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(match.name, style: AppTextStyles.title)),
              StatusBadge(label: match.status, color: AppColors.success),
            ],
          ),
          const SizedBox(height: 6),
          Text('${match.role} • ${match.location}', style: AppTextStyles.body),
          const SizedBox(height: 10),
          Text(match.lastMessage, style: AppTextStyles.muted),
          if (match.contactRevealed) ...[
            const SizedBox(height: 10),
            Text('Phone: ${match.phone.isEmpty ? 'Not shared' : match.phone}',
                style: AppTextStyles.body),
            Text('Email: ${match.email.isEmpty ? 'Not shared' : match.email}',
                style: AppTextStyles.body),
            const SizedBox(height: 10),
            Column(
              children: [
                SecondaryButton(
                  label: 'Call',
                  icon: Icons.call_rounded,
                  onPressed: phoneDigits.isEmpty
                      ? null
                      : () => _launchContact(
                            context,
                            Uri(scheme: 'tel', path: phoneDigits),
                          ),
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  label: 'WhatsApp',
                  icon: Icons.chat_rounded,
                  onPressed: phoneDigits.isEmpty
                      ? null
                      : () => _launchContact(
                            context,
                            Uri.parse('https://wa.me/$phoneDigits'),
                          ),
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  label: 'Email',
                  icon: Icons.email_rounded,
                  onPressed: match.email.trim().isEmpty
                      ? null
                      : () => _launchContact(
                            context,
                            Uri(
                              scheme: 'mailto',
                              path: match.email.trim(),
                            ),
                          ),
                ),
              ],
            ),
          ] else if (!match.chatEnabled) ...[
            const SizedBox(height: 10),
            const StatusBadge(
              label: 'Candidate has not unlocked direct communication.',
              color: AppColors.warning,
            ),
          ],
          const SizedBox(height: 14),
          PrimaryButton(
            label: match.chatEnabled ? 'Open Chat' : 'Chat Unavailable',
            onPressed: match.chatEnabled
                ? () => Navigator.of(context).pushNamed(
                      AppRoutes.employerPrivateChat,
                      arguments: match,
                    )
                : null,
          ),
        ],
      ),
    );
  }
}

class EmployerChatCard extends StatelessWidget {
  const EmployerChatCard({super.key, required this.match});

  final EmployerMatch match;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: match.chatEnabled
          ? () => Navigator.of(context).pushNamed(
                AppRoutes.employerPrivateChat,
                arguments: match,
              )
          : null,
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.elevatedCard,
            child: Icon(Icons.person_outline_rounded,
                color: AppColors.primaryPink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(match.name, style: AppTextStyles.label),
                Text(match.role, style: AppTextStyles.muted),
                const SizedBox(height: 4),
                Text(match.lastMessage, style: AppTextStyles.body),
              ],
            ),
          ),
          if (match.unreadCount > 0)
            StatusBadge(
                label: '${match.unreadCount}', color: AppColors.primaryPink),
        ],
      ),
    );
  }
}

class EmployerChatBubble extends StatelessWidget {
  const EmployerChatBubble(
      {super.key, required this.text, required this.isEmployer});

  final String text;
  final bool isEmployer;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isEmployer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isEmployer ? AppColors.primaryPink : AppColors.elevatedCard,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: AppTextStyles.body.copyWith(color: AppColors.white),
        ),
      ),
    );
  }
}

class UploadDocumentCard extends StatelessWidget {
  const UploadDocumentCard({
    super.key,
    required this.title,
    this.optional = false,
    this.onTap,
  });

  final String title;
  final bool optional;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.upload_file_rounded, color: AppColors.primaryPink),
          const SizedBox(width: 12),
          Expanded(
              child: Text(optional ? '$title optional' : title,
                  style: AppTextStyles.label)),
          const Icon(Icons.add_circle_outline_rounded,
              color: AppColors.secondaryText),
        ],
      ),
    );
  }
}

class TeamMemberCard extends StatelessWidget {
  const TeamMemberCard({super.key, required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
                Text(member.name, style: AppTextStyles.label),
                Text(member.email, style: AppTextStyles.muted),
              ],
            ),
          ),
          StatusBadge(label: member.role, color: AppColors.accentPurple),
        ],
      ),
    );
  }
}
