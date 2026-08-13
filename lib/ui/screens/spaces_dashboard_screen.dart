import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/misc.dart';

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

  Future<void> _loadCounts() async {
    final state = context.read<AppState>();
    final counts = <String, int>{};
    for (final space in state.spaces) {
      counts[space.id] = await state.countMembers(space.id);
    }
    if (mounted) setState(() => _counts = counts);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

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
              child: spaces.isEmpty
                  ? _EmptySpaces(
                      onCreate: widget.onCreate,
                      onJoin: widget.onJoin,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: spaces.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final space = spaces[index];
                        return _SpaceCard(
                          space: space,
                          memberCount: _counts[space.id],
                          onTap: () => widget.onSelect(space),
                        );
                      },
                    ),
            ),
            if (spaces.isNotEmpty)
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
  final VoidCallback onTap;

  const _SpaceCard({
    required this.space,
    required this.memberCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final isSplit = space.mode == SpaceMode.split;
    final modeColor = isSplit ? AppColors.primary : AppColors.positive;
    final modeLabel = isSplit ? l10n.splitMode : l10n.personalMode;
    final modeIcon = isSplit ? Icons.groups_outlined : Icons.person_outline;

    return Material(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.border,
            ),
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
                            Color(0xFF5B8A6E),
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
                          Text(
                            l10n.householdMembersCount(memberCount!),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 26,
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
            ],
          ),
        ),
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