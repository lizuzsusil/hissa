import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../ui/screens/dashboard_screen.dart';
import '../ui/screens/expense_detail_screen.dart';
import '../ui/screens/expenses_screen.dart';
import '../ui/screens/member_groups_screen.dart';
import '../ui/screens/notifications_screen.dart';
import '../ui/screens/pending_join_screen.dart';
import '../ui/screens/settle_screen.dart';
import '../ui/screens/space_screen.dart';

/// Resolves a notification (in-app or FCM push) into a deep link.
///
/// [open] is safe to call from any lifecycle state: it guards on the user being
/// signed in, attaches the repository to the referenced Space when the user is
/// a member of it, then pushes the target screen. Notifications that arrive
/// before the app is ready (cold start) should be [buffer]ed and flushed once
/// the flow is in the signed-in area.
class NotificationRouter {
  final GlobalKey<NavigatorState> navigatorKey;
  final AppState state;
  Map<String, dynamic>? _pending;

  NotificationRouter({required this.navigatorKey, required this.state});

  /// Defers a deep link until the app flow is ready to honour it.
  void buffer(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    _pending = data;
  }

  /// Routes any previously buffered deep link, if the app is signed in.
  Future<void> flush() async {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    await open(pending);
  }

  /// Deep-links to the screen described by an FCM `data` payload (the same
  /// structure as [AppNotification]).
  Future<void> open(Map<String, dynamic> data) async {
    if (!state.isLoggedIn) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final type = _parseType(data['type']);
    if (type == null) return;

    final spaceId = data['spaceId'] as String?;
    // A Space the user requested to join but is still awaiting approval is not
    // enterable: never select it (selectSpace already refuses, but we must not
    // even switch the dashboard's selected Space behind the scenes).
    final pendingSpaceId =
        spaceId != null && state.isPendingSpace(spaceId) ? spaceId : null;
    if (spaceId != null &&
        pendingSpaceId == null &&
        state.spaces.any((s) => s.id == spaceId)) {
      if (state.space?.id != spaceId) {
        await state.selectSpace(spaceId);
      }
    }

    // "Your join request was approved": land inside the newly joined Space
    // rather than pushing a request-management screen.
    if (type == NotificationType.spaceJoinApproved) {
      nav.popUntil((r) => r.isFirst);
      return;
    }

    // While the join/invitation request is still pending, the requester must
    // see the pending-approval state for that Space — not be dropped into
    // their currently selected Space.
    if (pendingSpaceId != null) {
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => PendingJoinScreen(spaceId: pendingSpaceId),
        ),
      );
      return;
    }

    nav.push(
      MaterialPageRoute<void>(builder: (_) => _targetScreen(type, data)),
    );
  }

  Widget _targetScreen(NotificationType type, Map<String, dynamic> data) {
    switch (type) {
      case NotificationType.expenseAdded:
      case NotificationType.expenseUpdated:
        final expense = _findExpense(data['eventKey'] as String?);
        if (expense != null) return ExpenseDetailScreen(expense: expense);
        return const ExpensesScreen();
      case NotificationType.settlementRecorded:
        // Settle only exists for Split Spaces; Personal has no dues.
        if (state.isPersonalMode) return const DashboardScreen();
        return const SettleScreen();
      case NotificationType.spaceJoinRequested:
      case NotificationType.spaceInvited:
        // The owner manages join requests / members here.
        return const SpaceScreen();
      case NotificationType.groupRequested:
      case NotificationType.groupApproved:
        return const MemberGroupsScreen();
      case NotificationType.spaceJoinApproved:
      case NotificationType.spaceJoinRejected:
      case NotificationType.groupRejected:
        // Rejections (and the approved-requester path handled above) have no
        // dedicated screen; the inbox explains the outcome.
        return const NotificationsScreen();
    }
  }

  Expense? _findExpense(String? id) {
    if (id == null) return null;
    for (final expense in state.repo.expenses) {
      if (expense.id == id) return expense;
    }
    return null;
  }

  NotificationType? _parseType(Object? raw) {
    if (raw is! String) return null;
    for (final type in NotificationType.values) {
      if (type.name == raw) return type;
    }
    return null;
  }
}
