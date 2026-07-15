import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final repository = const CandidateProfileRepository();
  late Future<List<CandidateDocumentNotificationData>> notificationsFuture =
      repository.loadDocumentNotifications();

  Future<void> _reload() async {
    setState(() {
      notificationsFuture = repository.loadDocumentNotifications();
    });
    await notificationsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Notifications',
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: [
        FutureBuilder<List<CandidateDocumentNotificationData>>(
          future: notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load notifications',
                message: snapshot.error.toString(),
              );
            }
            final notifications = snapshot.data ?? const [];
            if (notifications.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications yet',
                message: 'Document reminders and verification updates will appear here.',
              );
            }
            return Column(
              children: [
                for (final notification in notifications) ...[
                  _NotificationCard(notification: notification),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final CandidateDocumentNotificationData notification;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: notification.isRead
                ? AppColors.elevatedCard
                : AppColors.primaryPink.withValues(alpha: 0.16),
            child: Icon(
              _icon,
              color: notification.isRead ? AppColors.secondaryText : AppColors.primaryPink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.title, style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text(notification.body, style: AppTextStyles.body),
                const SizedBox(height: 6),
                Text(_dateText, style: AppTextStyles.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData get _icon {
    if (notification.notificationType.contains('expiring')) {
      return Icons.event_busy_rounded;
    }
    if (notification.notificationType.contains('replaced')) {
      return Icons.swap_horiz_rounded;
    }
    if (notification.notificationType.contains('pending')) {
      return Icons.pending_actions_rounded;
    }
    return Icons.verified_user_outlined;
  }

  String get _dateText {
    final date = DateTime.tryParse(
      notification.scheduledFor.isEmpty ? notification.createdAt : notification.scheduledFor,
    );
    if (date == null) return notification.createdAt;
    final label = notification.scheduledFor.isEmpty ? 'Created' : 'Reminder';
    return '$label: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
