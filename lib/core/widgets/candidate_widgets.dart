import 'package:flutter/material.dart';

import '../../features/candidate/models/candidate_models.dart';
import '../../features/supabase_backend/kaam_backend.dart';
import '../constants/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';
import 'primary_button.dart';
import 'privacy_badge.dart';
import 'secondary_button.dart';
import 'status_badge.dart';

class CandidateStatCard extends StatelessWidget {
  const CandidateStatCard({super.key, required this.stat, this.onTap});

  final CandidateStat stat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat.value,
              style: AppTextStyles.headline
                  .copyWith(color: AppColors.primaryPink)),
          const SizedBox(height: 6),
          Text(stat.label, style: AppTextStyles.label),
          const SizedBox(height: 4),
          Text(stat.note, style: AppTextStyles.muted),
        ],
      ),
    );
  }
}

class ProfileStrengthCard extends StatelessWidget {
  const ProfileStrengthCard({
    super.key,
    required this.value,
    required this.helperText,
  });

  final int value;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Profile Strength', style: AppTextStyles.title)),
              Text('$value%',
                  style: AppTextStyles.title
                      .copyWith(color: AppColors.primaryPink)),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            value: value / 100,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.primaryPink),
          ),
          const SizedBox(height: 12),
          Text(helperText, style: AppTextStyles.muted),
        ],
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primaryPink),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center, style: AppTextStyles.label),
        ],
      ),
    );
  }
}

class InterestRequestCard extends StatelessWidget {
  const InterestRequestCard({super.key, required this.request});

  final InterestRequest request;

  @override
  Widget build(BuildContext context) {
    final status = request.status.toLowerCase();
    return AppCard(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.requestDetails, arguments: request),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Text(request.company, style: AppTextStyles.title)),
              const StatusBadge(
                  label: 'Verified', icon: Icons.verified_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Text(request.role, style: AppTextStyles.label),
          const SizedBox(height: 6),
          Text('${request.salary} - ${request.location}',
              style: AppTextStyles.body),
          const SizedBox(height: 10),
          Text(request.message, style: AppTextStyles.muted),
          const SizedBox(height: 16),
          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Decline',
                    onPressed: () => Navigator.of(context).pushNamed(
                        AppRoutes.requestDetails,
                        arguments: request),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: 'Review',
                    onPressed: () => Navigator.of(context).pushNamed(
                        AppRoutes.requestDetails,
                        arguments: request),
                  ),
                ),
              ],
            )
          else
            StatusBadge(label: status, color: AppColors.accentPurple),
        ],
      ),
    );
  }
}

class MatchCard extends StatefulWidget {
  const MatchCard({super.key, required this.match});

  final MatchItem match;

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  bool revealing = false;

  Future<void> _revealContact() async {
    final matchId = widget.match.id ?? '';
    if (matchId.isEmpty) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reveal contact details?'),
            content: const Text(
              'Your phone number and email will be visible only to this matched employer.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Reveal')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => revealing = true);
    try {
      await const MatchRepository().revealCandidateContact(matchId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Contact details revealed for this match.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reveal contact details: $error')),
      );
    } finally {
      if (mounted) setState(() => revealing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(match.company, style: AppTextStyles.title)),
              StatusBadge(label: match.status, color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 8),
          Text('${match.role} - ${match.location}', style: AppTextStyles.body),
          const SizedBox(height: 8),
          Text(match.preview, style: AppTextStyles.muted),
          const SizedBox(height: 16),
          PrimaryButton(
            label: match.chatEnabled ? 'Open Chat' : 'Chat Locked',
            onPressed: match.chatEnabled
                ? () => Navigator.of(context)
                    .pushNamed(AppRoutes.privateChat, arguments: match)
                : null,
          ),
          if (match.canRevealContact && !match.contactRevealed) ...[
            const SizedBox(height: 10),
            SecondaryButton(
              label: revealing ? 'Revealing...' : 'Reveal My Contact Details',
              icon: Icons.lock_open_rounded,
              onPressed: revealing ? null : _revealContact,
            ),
          ],
        ],
      ),
    );
  }
}

class PrivacyModeCard extends StatelessWidget {
  const PrivacyModeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrivacyBadge(),
          SizedBox(height: 12),
          Text(
            'Your phone number and contact details are hidden until you accept an employer request.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class CandidateProfileHeader extends StatelessWidget {
  const CandidateProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.elevatedCard,
            child: Icon(Icons.person, size: 36, color: AppColors.primaryPink),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name not set', style: AppTextStyles.title),
                SizedBox(height: 4),
                Text('Preferred role not set', style: AppTextStyles.body),
                SizedBox(height: 4),
                Text('Location not set', style: AppTextStyles.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UploadDocumentCard extends StatelessWidget {
  const UploadDocumentCard(
      {super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.upload_file_rounded, color: AppColors.primaryPink),
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
          const Icon(Icons.add_circle_outline, color: AppColors.secondaryText),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.text, required this.isMe});

  final String text;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryPink : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isMe ? AppColors.primaryPink : AppColors.border),
        ),
        child: Text(
          text,
          style: TextStyle(
              color: isMe ? AppColors.white : AppColors.secondaryText),
        ),
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile(
      {super.key, required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPink),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: AppTextStyles.label)),
          const Icon(Icons.chevron_right, color: AppColors.mutedText),
        ],
      ),
    );
  }
}
