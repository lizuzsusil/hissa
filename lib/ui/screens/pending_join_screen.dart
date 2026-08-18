import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/misc.dart';

/// The requester-facing pending state for a Space whose join request is still
/// awaiting the owner's approval.
///
/// Reached from a notification deep link (see [NotificationRouter]) so the
/// requester is never dropped into their currently selected Space while the
/// request is unresolved. Pulling to refresh (or a newly arrived
/// "approved" notification) re-checks the request: when the owner approves,
/// the user is dropped straight into their new Space.
class PendingJoinScreen extends StatefulWidget {
  final String spaceId;

  const PendingJoinScreen({super.key, required this.spaceId});

  @override
  State<PendingJoinScreen> createState() => _PendingJoinScreenState();
}

class _PendingJoinScreenState extends State<PendingJoinScreen> {
  late final AppState _state;
  int _notificationCount = 0;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _notificationCount = _state.notifications.length;
    _state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted || _leaving) return;
    // The owner's decision lands in the requester's inbox as a new
    // notification (`spaceJoinApproved`/`spaceJoinRejected`), so a change in
    // the inbox means it is worth re-checking the pending request.
    final count = _state.notifications.length;
    if (count == _notificationCount) return;
    _notificationCount = count;
    unawaited(_refresh());
  }

  /// Re-checks the pending request. When it was approved, the requester is
  /// dropped straight into the Space; when it was rejected, back to the Spaces
  /// dashboard (the pending card is gone from there).
  Future<void> _refresh() async {
    if (_leaving) return;
    final state = _state;
    final approved = await state.refreshPendingSpaceJoinRequests();
    if (!mounted || _leaving) return;
    if (approved.isNotEmpty) {
      await _enterSpace(state, approved.first.id);
      return;
    }
    // The request is no longer pending and the user was not approved — the
    // owner rejected it (or the Space no longer exists).
    if (!state.isPendingSpace(widget.spaceId) &&
        !state.spaces.any((s) => s.id == widget.spaceId)) {
      _leaving = true;
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _enterSpace(AppState state, String spaceId) async {
    _leaving = true;
    await state.selectSpace(spaceId);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spaceName = state.spaceNameById(widget.spaceId) ?? l10n.space;

    // The owner approved while this screen was open: leave so the shell (now
    // showing the selected Space) takes over.
    if (!_leaving && !state.isPendingSpace(widget.spaceId)) {
      final isMember = state.spaces.any((s) => s.id == widget.spaceId);
      if (isMember) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _enterSpace(state, widget.spaceId),
        );
      } else {
        _leaving = true;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.space)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              SizedBox(
                height: constraints.maxHeight - 32,
                child: EmptyState(
                  icon: Icons.hourglass_top_rounded,
                  title: spaceName,
                  message: l10n.joinRequestPendingDescription,
                  action: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 15,
                                color: isDark
                                    ? AppColors.primaryBright
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.pendingApproval,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.primaryBright
                                      : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
