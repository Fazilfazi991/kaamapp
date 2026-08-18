import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/private_profile_photo_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/skill_chip.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/employer_models.dart';
import '../models/employer_interest_state_store.dart';
import '../models/employer_saved_state_store.dart';
import '../../supabase_backend/kaam_backend.dart';

class EmployerBottomNav extends StatelessWidget {
  const EmployerBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _routes = [
    AppRoutes.employerDashboard,
    AppRoutes.employerCandidateSearch,
    AppRoutes.employerSavedCandidates,
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
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(_routes[index], (route) => route.isFirst);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(
          icon: Icon(Icons.manage_search_rounded),
          label: 'Hire',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark_border_rounded),
          selectedIcon: Icon(Icons.bookmark_rounded),
          label: 'Saved',
        ),
        NavigationDestination(
          icon: Icon(Icons.handshake_outlined, size: 30),
          selectedIcon: Icon(Icons.handshake_rounded, size: 34),
          label: 'Matches',
        ),
        NavigationDestination(
          icon: Icon(Icons.outbox_rounded),
          label: 'Interests',
        ),
        NavigationDestination(
          icon: Icon(Icons.business_outlined),
          label: 'Company',
        ),
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
    this.onSavedChanged,
  });

  final EmployerCandidate candidate;
  final bool showActions;
  final ValueChanged<bool>? onSavedChanged;

  @override
  State<CandidateMiniProfileCard> createState() =>
      _CandidateMiniProfileCardState();
}

class _CandidateMiniProfileCardState extends State<CandidateMiniProfileCard> {
  late bool saved = widget.candidate.isSaved;
  bool saving = false;
  final repository = const EmployerRepository();

  @override
  void initState() {
    super.initState();
    EmployerInterestStateStore.instance.addListener(_interestChanged);
    EmployerSavedStateStore.instance.addListener(_interestChanged);
  }

  @override
  void dispose() {
    EmployerInterestStateStore.instance.removeListener(_interestChanged);
    EmployerSavedStateStore.instance.removeListener(_interestChanged);
    super.dispose();
  }

  void _interestChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(CandidateMiniProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidate.candidateProfileId !=
        widget.candidate.candidateProfileId) {
      saved = widget.candidate.isSaved;
    }
  }

  Future<void> _toggleSaved() async {
    if (saving) return;
    final candidateId = widget.candidate.candidateProfileId ?? '';
    if (candidateId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not update this candidate.')),
      );
      return;
    }
    final previous =
        EmployerSavedStateStore.instance.isSavedFor(candidateId) ?? saved;
    setState(() {
      saving = true;
      saved = !previous;
    });
    try {
      if (saved) {
        await repository.saveCandidate(candidateId);
      } else {
        await repository.removeSavedCandidate(candidateId);
      }
      if (!mounted) return;
      EmployerSavedStateStore.instance.setSaved(candidateId, saved);
      widget.onSavedChanged?.call(saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Candidate saved.' : 'Removed from saved candidates.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => saved = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not update this candidate. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    final isSaved = EmployerSavedStateStore.instance
            .isSavedFor(candidate.candidateProfileId) ??
        saved;
    final interestStatus = EmployerInterestStateStore.instance
            .statusFor(candidate.candidateProfileId) ??
        candidate.interestStatus;
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
                    Row(children: [
                      Flexible(
                          child: Text(candidate.displayName,
                              style: AppTextStyles.title)),
                      if (candidate.isManuallyVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded,
                            size: 16, color: AppColors.success),
                        const SizedBox(width: 3),
                        const Text('KAAM Verified',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.success)),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      candidate.role,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${candidate.experience} • ${candidate.location}',
            style: AppTextStyles.muted,
          ),
          Text(
            'Expected ${candidate.expectedSalary} • ${candidate.availability}',
            style: AppTextStyles.muted,
          ),
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
          const Text(
            'Contact details unlock only after mutual approval.',
            style: AppTextStyles.muted,
          ),
          if (widget.showActions) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: isSaved ? 'Saved' : 'Save',
                    icon: isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    onPressed: saving ? null : _toggleSaved,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    label: 'View Profile',
                    icon: Icons.person_outline_rounded,
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRoutes.employerCandidateProfile,
                      arguments: candidate,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (interestStatus == 'pending')
              const PrimaryButton(
                label: 'Interest Sent',
                icon: Icons.schedule_rounded,
                onPressed: null,
              )
            else if (interestStatus == 'accepted')
              PrimaryButton(
                label: 'View Match',
                icon: Icons.handshake_rounded,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.employerMatches),
              )
            else
              PrimaryButton(
                label: 'Show Interest',
                icon: Icons.handshake_rounded,
                onPressed: () => Navigator.of(context).pushNamed(
                  AppRoutes.employerSendInterest,
                  arguments: candidate,
                ),
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
    return PrivateProfilePhotoAvatar(
      path: candidate.profilePhotoUrl ?? '',
      initials: profileInitials(candidate.displayName, fallback: 'C'),
      candidateId: candidate.candidateProfileId,
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
              PrivateProfilePhotoAvatar(
                path: request.candidatePhotoUrl,
                candidateId: request.candidateId,
                initials: profileInitials(
                  request.candidateName,
                  fallback: 'C',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(request.candidateName, style: AppTextStyles.title),
              ),
              StatusBadge(label: request.status, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.jobTitle,
            style: AppTextStyles.body.copyWith(color: AppColors.white),
          ),
          Text(
            '${request.salary} • ${request.location}',
            style: AppTextStyles.muted,
          ),
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
                          'This interest request will be withdrawn.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Keep'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel Request'),
                          ),
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
              PrivateProfilePhotoAvatar(
                path: match.profilePhotoUrl,
                candidateId: match.candidateProfileId,
                initials: profileInitials(match.name, fallback: 'C'),
              ),
              const SizedBox(width: 12),
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
            Text(
              'Phone: ${match.phone.isEmpty ? 'Not shared' : match.phone}',
              style: AppTextStyles.body,
            ),
            Text(
              'Email: ${match.email.isEmpty ? 'Not shared' : match.email}',
              style: AppTextStyles.body,
            ),
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
                            Uri(scheme: 'mailto', path: match.email.trim()),
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
                ? () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.employerPrivateChat, arguments: match)
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
          ? () => Navigator.of(
                context,
              ).pushNamed(AppRoutes.employerPrivateChat, arguments: match)
          : null,
      child: Row(
        children: [
          PrivateProfilePhotoAvatar(
            path: match.profilePhotoUrl,
            candidateId: match.candidateProfileId,
            initials: profileInitials(match.name, fallback: 'C'),
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
              label: '${match.unreadCount}',
              color: AppColors.primaryPink,
            ),
        ],
      ),
    );
  }
}

class EmployerChatBubble extends StatelessWidget {
  const EmployerChatBubble({
    super.key,
    required this.text,
    required this.isEmployer,
  });

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
            child: Text(
              optional ? '$title optional' : title,
              style: AppTextStyles.label,
            ),
          ),
          const Icon(
            Icons.add_circle_outline_rounded,
            color: AppColors.secondaryText,
          ),
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
            child: Icon(
              Icons.person_outline_rounded,
              color: AppColors.primaryPink,
            ),
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
