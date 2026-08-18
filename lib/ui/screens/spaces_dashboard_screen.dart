import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/misc.dart';
import '../widgets/motion.dart';

/// Post-login landing screen. Lists every Space the user belongs to with its
/// mode and member count, and offers Create Space, Join Space and Sign Out.
///
/// Selecting a Space opens its dashboard via [onSelect]; Create/Join flow to
/// the setup screens via [onCreate]/[onJoin]; [onSignOut] returns to auth.
class SpacesDashboardScreen extends StatefulWidget {
  final ValueChanged<Space> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onSignOut;

  const SpacesDashboardScreen({
    super.key,
    required this.onSelect,
    required this.onCreate,
    required this.onJoin,
    required this.onSignOut,
  });

  @override
  State<SpacesDashboardScreen> createState() => _SpacesDashboardScreenState();
}

class _SpacesDashboardScreenState extends State<SpacesDashboardScreen> {
  Map<String, int> _counts = {};
  List<String> _loadedIds = const [];

  @override
  void initState() {
    super.initState();
    // Surface any Spaces the user requested to join while away from the join
    // screen (e.g. after a fresh sign-in) as non-enterable pending cards.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPending());
  }

  Future<void> _loadPending() async {
    await context.read<AppState>().refreshPendingSpaceJoinRequests();
  }

  /// Pull-to-refresh: re-queries membership Spaces, pending join requests and
  /// member counts so newly approved Spaces appear without re-signing in.
  Future<void> _refresh() async {
    final state = context.read<AppState>();
    await state.refreshSpaces();
    await state.refreshPendingSpaceJoinRequests();
    await _loadCounts();
  }

  Future<void> _loadCounts() async {
    final state = context.read<AppState>();
    final counts = <String, int>{};
    for (final space in state.spaces) {
      counts[space.id] = await state.countMembers(space.id);
    }
    if (mounted) setState(() => _counts = counts);
  }

  /// Marks [space] as the one to open automatically on the next launch, or
  /// clears the preference when it is already the default.
  Future<void> _toggleDefault(Space space) async {
    final state = context.read<AppState>();
    final l10n = context.l10n;
    final isDefault = state.defaultSpaceId == space.id;
    await state.setDefaultSpace(isDefault ? null : space.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isDefault
                ? l10n.defaultSpaceRemovedMessage
                : l10n.defaultSpaceSetMessage(space.name),
          ),
        ),
      );
  }

  Future<void> _confirmSignOut() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOutTitle),
        content: Text(l10n.signOutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final spaces = state.spaces;
    final pendingSpaces = state.pendingSpaces;
    final defaultSpaceId = state.defaultSpaceId;
    // The "open by default" toggle only makes sense when there are several
    // Spaces to choose from (a single Space is always entered automatically).
    final showDefaultToggle = spaces.length > 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    // Spaces awaiting approval are shown (with their name) but can never be
    // entered until the owner approves the request.
    final pendingItems = <Widget>[
      if (pendingSpaces.isNotEmpty) ...[
        Row(
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              size: 15,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.pendingApprovalSection,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        for (final pending in pendingSpaces) _PendingSpaceCard(space: pending),
      ],
    ];

    final ids = spaces.map((s) => s.id).toList();
    if (!listEquals(ids, _loadedIds)) {
      _loadedIds = ids;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadCounts();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.mySpaces,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.mySpacesSubtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconAction(
                    icon: Icons.logout_rounded,
                    foreground: AppColors.negative,
                    size: 46,
                    onPressed: _confirmSignOut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => RefreshIndicator(
                  onRefresh: _refresh,
                  child: spaces.isEmpty && pendingSpaces.isEmpty
                      // Keep the empty state vertically centred like before;
                      // the ListView only exists to allow pull-to-refresh.
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: constraints.maxHeight,
                              child: _EmptySpaces(
                                onCreate: widget.onCreate,
                                onJoin: widget.onJoin,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          itemCount: pendingItems.length + spaces.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index < pendingItems.length) {
                              return pendingItems[index];
                            }
final space = spaces[index - pendingItems.length];
                          return Reveal(
                            delay: Duration(milliseconds: 60 * index),
                            child: _SpaceCard(
                              space: space,
                              memberCount: _counts[space.id],
                              isDefault: space.id == defaultSpaceId,
                              showDefaultToggle: showDefaultToggle,
                              onToggleDefault: () => _toggleDefault(space),
                              onTap: () => widget.onSelect(space),
                            ),
                          );
                          },
                        ),
                ),
              ),
            ),
            if (spaces.isNotEmpty || pendingSpaces.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    PrimaryButton(
                      label: l10n.createSpace,
                      icon: Icons.add_rounded,
                      onPressed: widget.onCreate,
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: l10n.joinSpace,
                      icon: Icons.group_add_outlined,
                      onPressed: widget.onJoin,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpaceCard extends StatelessWidget {
  final Space space;
  final int? memberCount;
  final bool isDefault;
  final bool showDefaultToggle;
  final VoidCallback onTap;
  final VoidCallback onToggleDefault;

  const _SpaceCard({
    required this.space,
    required this.memberCount,
    this.isDefault = false,
    this.showDefaultToggle = false,
    required this.onTap,
    required this.onToggleDefault,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final isSplit = space.mode == SpaceMode.split;
    final modeColor = isSplit ? AppColors.primary : AppColors.positive;
    final modeLabel = isSplit ? l10n.splitMode : l10n.personalMode;
    final modeIcon = isSplit ? Icons.groups_outlined : Icons.person_outline;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? AppColors.borderDark
                : (isDefault ? AppColors.primary : Colors.transparent),
            width: isDefault ? 1.6 : 1,
          ),
          boxShadow: cardShadow(),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: isSplit
                    ? AppColors.heroGradient
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF34C07E),
                          AppColors.positive,
                        ],
                      ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(modeIcon, size: 26, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    space.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: modeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(modeIcon, size: 13, color: modeColor),
                            const SizedBox(width: 5),
                            Text(
                              modeLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: modeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (memberCount != null) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            l10n.spaceMembersCount(memberCount!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (showDefaultToggle) ...[
              IconButton(
                key: ValueKey('default_toggle_${space.id}'),
                tooltip: l10n.openByDefault,
                onPressed: onToggleDefault,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isDefault
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 24,
                  color: isDefault
                      ? Colors.amber.shade600
                      : (isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 26,
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// A Space the current user requested to join but has not been approved for
/// yet. Shown so the requester can see their requested Space, but deliberately
/// not tappable: the user can only open a Space once they are a member.
class _PendingSpaceCard extends StatelessWidget {
  final Space space;

  const _PendingSpaceCard({required this.space});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    return Container(
      key: ValueKey('pending_space_${space.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 24,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  space.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.pendingApproval,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _EmptySpaces extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _EmptySpaces({required this.onCreate, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      icon: Icons.workspaces_outline,
      title: l10n.noSpacesYet,
      message: l10n.noSpacesMessage,
      action: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            PrimaryButton(
              label: l10n.createSpace,
              icon: Icons.add_rounded,
              onPressed: onCreate,
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: l10n.joinSpace,
              icon: Icons.group_add_outlined,
              onPressed: onJoin,
            ),
          ],
        ),
      ),
    );
  }
}