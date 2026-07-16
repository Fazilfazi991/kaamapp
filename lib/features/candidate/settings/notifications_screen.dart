import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../notifications/notification_models.dart';
import '../../notifications/notification_repository.dart';
import '../../notifications/push_notification_service.dart';
import '../../supabase_backend/kaam_backend.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.role = KaamRole.candidate});

  final KaamRole role;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final repository = const KaamNotificationRepository();
  bool unreadOnly = false;
  late Future<_NotificationCenterData> dataFuture = _load();

  Future<_NotificationCenterData> _load() async {
    final results = await Future.wait([
      repository.loadNotifications(unreadOnly: unreadOnly),
      repository.loadPreferences(),
    ]);
    return _NotificationCenterData(
      notifications: results[0] as List<KaamNotification>,
      preferences: results[1] as KaamNotificationPreferences,
    );
  }

  Future<void> _reload() async {
    setState(() => dataFuture = _load());
    await dataFuture;
  }

  Future<void> _markAllRead() async {
    await repository.markAllRead();
    await _reload();
  }

  Future<void> _toggleFilter(bool unread) async {
    setState(() {
      unreadOnly = unread;
      dataFuture = _load();
    });
  }

  Future<void> _openNotification(KaamNotification notification) async {
    if (notification.isUnread) {
      await repository.markRead(notification.id);
    }
    final route = KaamNotificationDeepLinks.routeFor(
      role: widget.role,
      type: notification.type,
      actionRoute: notification.actionRoute,
    );
    if (!mounted) return;
    Navigator.of(context).pushNamed(route).then((_) => _reload());
  }

  Future<void> _savePreference(
    KaamNotificationPreferences current,
    KaamNotificationPreferences updated,
  ) async {
    await repository.savePreferences(updated);
    if (updated.pushEnabled && !current.pushEnabled) {
      await KaamPushNotificationService.instance.requestPermissionAndRegister();
    }
    await _reload();
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
        FutureBuilder<_NotificationCenterData>(
          future: dataFuture,
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
            final data = snapshot.data ??
                const _NotificationCenterData(
                  notifications: [],
                  preferences: KaamNotificationPreferences(),
                );
            final unreadCount =
                data.notifications.where((item) => item.isUnread).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NotificationToolbar(
                  unreadOnly: unreadOnly,
                  unreadCount: unreadCount,
                  onFilterChanged: _toggleFilter,
                  onMarkAllRead: unreadCount == 0 ? null : _markAllRead,
                ),
                const SizedBox(height: 14),
                if (data.notifications.isEmpty)
                  const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications yet',
                    message:
                        'Account, message, match, and verification updates will appear here.',
                  )
                else
                  for (final notification in data.notifications) ...[
                    _NotificationCard(
                      notification: notification,
                      onTap: () => _openNotification(notification),
                    ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 18),
                _PreferenceCard(
                  preferences: data.preferences,
                  onChanged: (updated) =>
                      _savePreference(data.preferences, updated),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NotificationCenterData {
  const _NotificationCenterData({
    required this.notifications,
    required this.preferences,
  });

  final List<KaamNotification> notifications;
  final KaamNotificationPreferences preferences;
}

class _NotificationToolbar extends StatelessWidget {
  const _NotificationToolbar({
    required this.unreadOnly,
    required this.unreadCount,
    required this.onFilterChanged,
    required this.onMarkAllRead,
  });

  final bool unreadOnly;
  final int unreadCount;
  final ValueChanged<bool> onFilterChanged;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('All')),
              ButtonSegment(value: true, label: Text('Unread')),
            ],
            selected: {unreadOnly},
            onSelectionChanged: (values) => onFilterChanged(values.first),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$unreadCount unread',
              textAlign: TextAlign.center,
              style: AppTextStyles.muted,
            ),
          ),
          IconButton(
            tooltip: 'Mark all read',
            onPressed: onMarkAllRead,
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final KaamNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderColor:
          notification.isUnread ? AppColors.primaryPink : AppColors.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: notification.isUnread
                ? AppColors.primaryPink.withValues(alpha: 0.16)
                : AppColors.elevatedCard,
            child: Icon(
              _iconForType(notification.type),
              color: notification.isUnread
                  ? AppColors.primaryPink
                  : AppColors.secondaryText,
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
                Text(_dateText(notification.createdAt),
                    style: AppTextStyles.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    if (type.contains('message')) return Icons.chat_bubble_outline_rounded;
    if (type.contains('match') || type.contains('interest')) {
      return Icons.handshake_outlined;
    }
    if (type.contains('document') || type.contains('company')) {
      return Icons.verified_user_outlined;
    }
    return Icons.notifications_active_outlined;
  }

  String _dateText(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.preferences, required this.onChanged});

  final KaamNotificationPreferences preferences;
  final ValueChanged<KaamNotificationPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Preferences', style: AppTextStyles.title),
          const SizedBox(height: 10),
          _SwitchRow(
            title: 'Push notifications',
            value: preferences.pushEnabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(pushEnabled: value)),
          ),
          _SwitchRow(
            title: 'In-app notifications',
            value: preferences.inAppEnabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(inAppEnabled: value)),
          ),
          _SwitchRow(
            title: 'New messages',
            value: preferences.newMessagesEnabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(newMessagesEnabled: value)),
          ),
          _SwitchRow(
            title: 'Interests and matches',
            value: preferences.interestsAndMatchesEnabled,
            onChanged: (value) => onChanged(
              preferences.copyWith(interestsAndMatchesEnabled: value),
            ),
          ),
          _SwitchRow(
            title: 'Document updates',
            value: preferences.documentUpdatesEnabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(documentUpdatesEnabled: value)),
          ),
          _SwitchRow(
            title: 'Account and security',
            value: preferences.accountSecurityEnabled,
            onChanged: (value) =>
                onChanged(preferences.copyWith(accountSecurityEnabled: value)),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppTextStyles.body),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primaryPink,
    );
  }
}
