import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/misc.dart' show EmptyState;

/// The signed-in user's in-app notification inbox. Fed in real time by the
/// repository's `notifications` listener (Firestore-driven; no Cloud
/// Functions / push required). Opening the screen marks everything as read.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final notifications = state.notifications;
    final readAt = state.notificationsReadAt;

    // Opening the inbox marks the current batch as read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.unreadNotificationCount > 0) {
        state.markNotificationsRead();
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifications), centerTitle: false),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: notifications.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: constraints.maxHeight,
                      child: EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: l10n.noNotifications,
                        message: l10n.noNotificationsMessage,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final note = notifications[index];
                  final unread = note.createdAt.isAfter(readAt);
                  return _NotificationTile(
                    notification: note,
                    unread: unread,
                    onTap: () => _openNotification(context, note),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    AppNotification note,
  ) async {
    final state = context.read<AppState>();
    final spaceId = note.spaceId;
    if (spaceId != null && state.spaces.any((s) => s.id == spaceId)) {
      await state.selectSpace(spaceId);
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool unread;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final bg = unread
        ? AppColors.primary.withValues(alpha: 0.08)
        : (isDark ? AppColors.surfaceDark : Colors.white);
    final border = unread
        ? AppColors.primary.withValues(alpha: 0.35)
        : (isDark ? AppColors.borderDark : AppColors.border);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MemberAvatar(name: notification.actorName, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleFor(l10n, notification.type),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${notification.displayActor}'
                    '${notification.spaceId != null ? ' · ${l10n.inSpace}' : ''}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatRelativeDay(notification.createdAt, l10n: l10n),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _titleFor(AppLocalizations l10n, NotificationType type) {
    return switch (type) {
      NotificationType.expenseAdded => l10n.notificationExpenseAdded,
      NotificationType.expenseUpdated => l10n.notificationExpenseUpdated,
      NotificationType.settlementRecorded =>
        l10n.notificationSettlementRecorded,
      NotificationType.spaceInvited => l10n.notificationSpaceInvited,
      NotificationType.spaceJoinRequested =>
        l10n.notificationSpaceJoinRequested,
      NotificationType.spaceJoinApproved => l10n.notificationSpaceJoinApproved,
      NotificationType.spaceJoinRejected => l10n.notificationSpaceJoinRejected,
      NotificationType.groupRequested => l10n.notificationGroupRequested,
      NotificationType.groupApproved => l10n.notificationGroupApproved,
      NotificationType.groupRejected => l10n.notificationGroupRejected,
    };
  }
}
