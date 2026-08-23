import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import 'avatars.dart';
import 'buttons.dart';
import 'cards.dart';
import 'dialogs.dart';
import 'misc.dart';
import 'motion.dart';
import 'swipe_reveal.dart';
import 'toasts.dart';

/// Reusable core for My Spaces — used by both the login dashboard and the
/// Settings-embedded screen. Header/AppBar is owned by the caller so the two
/// entry points can have different navigation while sharing the same list,
/// swipe actions, default-toggle and pending handling.
class SpacesView extends StatefulWidget {
  final ValueChanged<Space> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback? onSignOut;
  final bool showSignOut;

  const SpacesView({
    super.key,
    required this.onSelect,
    required this.onCreate,
    required this.onJoin,
    this.onSignOut,
    this.showSignOut = true,
  });

  @override
  State<SpacesView> createState() => _SpacesViewState();
}

class _SpacesViewState extends State<SpacesView> {
  Map<String, int> _counts = {};
  Map<String, List<String>> _memberNames = {};
  List<String> _loadedIds = const [];

  static const int _actionCountdownSeconds = 10;
  Timer? _actionTimer;
  String? _pendingSpaceId;
  bool _pendingIsDelete = false;
  final ValueNotifier<int> _countdown = ValueNotifier(_actionCountdownSeconds);
  final Map<String, bool> _openReveals = {};

  @override
  void dispose() {
    _actionTimer?.cancel();
    _countdown.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPending());
  }

  Future<void> _loadPending() async {
    await context.read<AppState>().refreshPendingSpaceJoinRequests();
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    await state.refreshSpaces();
    await state.refreshPendingSpaceJoinRequests();
    await _loadCounts();
  }

  Future<void> _loadCounts() async {
    final state = context.read<AppState>();
    final counts = <String, int>{};
    final names = <String, List<String>>{};
    for (final space in state.spaces) {
      counts[space.id] = await state.countMembers(space.id);
      try {
        final members = await state.repo.fetchSpaceMembers(space.id);
        names[space.id] = [for (final m in members) if (m.name.trim().isNotEmpty) m.name];
      } catch (_) {
        names[space.id] = const [];
      }
    }
    if (mounted) {
      setState(() {
        _counts = counts;
        _memberNames = names;
      });
    }
  }

  Future<void> _toggleDefault(Space space) async {
    final state = context.read<AppState>();
    final l10n = context.l10n;
    final isDefault = state.defaultSpaceId == space.id;
    await state.setDefaultSpace(isDefault ? null : space.id);
    if (!mounted) return;
    showToast(
      context,
      isDefault ? l10n.defaultSpaceRemovedMessage : l10n.defaultSpaceSetMessage(space.name),
      type: ToastType.success,
    );
  }

  Widget _buildSpaceTile({
    required AppState state,
    required Space space,
    required int index,
    required bool showDefaultToggle,
    required String? defaultSpaceId,
  }) {
    final l10n = context.l10n;
    final isDelete = state.isOwnerOf(space.id);
    return Reveal(
      delay: Duration(milliseconds: 60 * index),
      child: SwipeRevealAction(
        actionWidth: 88,
        onOpenChanged: (open) => _openReveals[space.id] = open,
        child: (dismiss) => _SpaceCard(
          key: ValueKey('space_card_${space.id}'),
          space: space,
          memberCount: _counts[space.id],
          memberNames: _memberNames[space.id],
          isDefault: space.id == defaultSpaceId,
          showDefaultToggle: showDefaultToggle,
          onToggleDefault: () => _toggleDefault(space),
          onTap: () {
            if (_openReveals[space.id] ?? false) {
              dismiss();
            } else {
              widget.onSelect(space);
            }
          },
        ),
        action: (dismiss) => _SpaceActionButton(
          key: ValueKey('space_action_${space.id}'),
          icon: isDelete ? Icons.delete_outline_rounded : Icons.logout_rounded,
          label: isDelete ? l10n.deleteSpace : l10n.leaveSpace,
          onPressed: () {
            dismiss();
            _onSpaceAction(space, isDelete: isDelete);
          },
        ),
      ),
    );
  }

  Future<void> _onSpaceAction(Space space, {required bool isDelete}) async {
    final state = context.read<AppState>();
    final uid = state.currentUserId;
    if (!isDelete && uid != null) {
      final outstanding = await state.outstandingDuesFor(space.id, uid);
      if (!mounted) return;
      if (!outstanding.isZero) {
        showToast(context, context.l10n.leaveBlockedOutstanding, type: ToastType.danger);
        return;
      }
    }
    _beginPendingAction(space, isDelete: isDelete);
  }

  void _beginPendingAction(Space space, {required bool isDelete}) {
    _actionTimer?.cancel();
    _pendingSpaceId = space.id;
    _pendingIsDelete = isDelete;
    _countdown.value = _actionCountdownSeconds;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: Duration(seconds: _actionCountdownSeconds + 1),
          content: ValueListenableBuilder<int>(
            valueListenable: _countdown,
            builder: (context, seconds, _) => Text(
              isDelete ? l10n.deletingSpaceIn(space.name, seconds) : l10n.leavingSpaceIn(space.name, seconds),
            ),
          ),
          action: SnackBarAction(label: l10n.undo, onPressed: _undoPendingAction),
        ),
      );
    _actionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final next = _countdown.value - 1;
      if (next <= 0) {
        t.cancel();
        _countdown.value = 0;
        _executePendingAction();
      } else {
        _countdown.value = next;
      }
    });
  }

  void _undoPendingAction() {
    _actionTimer?.cancel();
    _actionTimer = null;
    _pendingSpaceId = null;
    _countdown.value = _actionCountdownSeconds;
    if (!mounted) return;
    showToast(context, context.l10n.spaceActionCancelled);
  }

  Future<void> _executePendingAction() async {
    final spaceId = _pendingSpaceId;
    final isDelete = _pendingIsDelete;
    _pendingSpaceId = null;
    _actionTimer = null;
    _countdown.value = _actionCountdownSeconds;
    if (spaceId == null || !mounted) return;
    final state = context.read<AppState>();
    final l10n = context.l10n;
    final succeeded = isDelete ? await state.deleteSpace(spaceId) : await state.leaveSpace(spaceId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (succeeded) {
      showToast(context, isDelete ? l10n.spaceDeleted : l10n.spaceLeft, type: ToastType.success);
    }
    await state.refreshSpaces();
    if (mounted) await _loadCounts();
  }

  Future<void> _confirmSignOut() async {
    if (widget.onSignOut == null) return;
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.signOutTitle,
      message: l10n.signOutMessage,
      confirmLabel: l10n.signOut,
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (confirmed) widget.onSignOut!.call();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final spaces = state.spaces;
    final ownedSpaces = state.ownedSpaces;
    final joinedSpaces = state.joinedSpaces;
    final pendingSpaces = state.pendingSpaces;
    final defaultSpaceId = state.defaultSpaceId;
    final showDefaultToggle = (ownedSpaces.length + joinedSpaces.length) > 1;
    final l10n = context.l10n;

    final pendingItems = <Widget>[
      if (pendingSpaces.isNotEmpty) ...[
        Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(l10n.pendingApprovalSection, style: AppText.labelM.copyWith(color: AppColors.primary)),
          ],
        ),
        for (final pending in pendingSpaces) _PendingSpaceCard(space: pending),
      ],
    ];

    final ids = <String>[...ownedSpaces.map((s) => s.id), ...joinedSpaces.map((s) => s.id)];
    if (!listEquals(ids, _loadedIds)) {
      _loadedIds = ids;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadCounts();
      });
    }

    final tiles = <Widget>[];
    var cardIndex = 0;
    for (final pending in pendingItems) {
      tiles.add(pending);
      cardIndex++;
    }
    if (ownedSpaces.isNotEmpty) {
      tiles.add(SectionHeader(title: l10n.yourSpaces));
      for (final space in ownedSpaces) {
        tiles.add(_buildSpaceTile(state: state, space: space, index: cardIndex, showDefaultToggle: showDefaultToggle, defaultSpaceId: defaultSpaceId));
        cardIndex++;
      }
    }
    if (joinedSpaces.isNotEmpty) {
      tiles.add(SectionHeader(title: l10n.joinedSpaces));
      for (final space in joinedSpaces) {
        tiles.add(_buildSpaceTile(state: state, space: space, index: cardIndex, showDefaultToggle: showDefaultToggle, defaultSpaceId: defaultSpaceId));
        cardIndex++;
      }
    }

    // For standalone dashboard we render the header here; embedded version
    // (settings) hides it because the Scaffold AppBar already provides navigation.
    final header = widget.showSignOut
        ? Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.md, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.mySpaces, style: AppText.displayM.copyWith(fontSize: 28, letterSpacing: -0.6, color: context.palette.textPrimary)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(l10n.mySpacesSubtitle, style: AppText.labelL.copyWith(fontWeight: FontWeight.w500, color: context.palette.textSecondary)),
                    ],
                  ),
                ),
                if (widget.onSignOut != null)
                  IconAction(
                    icon: Icons.logout_rounded,
                    tooltip: l10n.signOut,
                    foreground: AppColors.negative,
                    size: 46,
                    onPressed: _confirmSignOut,
                  ),
              ],
            ),
          )
        : const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        if (widget.showSignOut) const SizedBox(height: AppSpacing.md),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => RefreshIndicator(
              onRefresh: _refresh,
              child: (ownedSpaces.isEmpty && joinedSpaces.isEmpty && pendingSpaces.isEmpty)
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [SizedBox(height: constraints.maxHeight, child: _EmptySpaces(onCreate: widget.onCreate, onJoin: widget.onJoin))],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl + AppSpacing.xs),
                      itemCount: tiles.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) => tiles[index],
                    ),
            ),
          ),
        ),
        if (spaces.isNotEmpty || pendingSpaces.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            child: Row(
              children: [
                Expanded(child: _QuickActionCard(icon: Icons.add_rounded, label: l10n.createSpace, accent: AppColors.primary, onTap: widget.onCreate)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _QuickActionCard(icon: Icons.group_add_outlined, label: l10n.joinSpace, accent: AppColors.info, onTap: widget.onJoin)),
              ],
            ),
          ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.label, required this.accent, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      child: Row(
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(gradient: AppGradients.tint(accent, alpha: 0.18), borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(icon, size: 22, color: accent)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.titleS.copyWith(color: p.textPrimary))),
        ],
      ),
    );
  }
}

class _SpaceCard extends StatelessWidget {
  final Space space;
  final int? memberCount;
  final List<String>? memberNames;
  final bool isDefault;
  final bool showDefaultToggle;
  final VoidCallback onTap;
  final VoidCallback onToggleDefault;
  const _SpaceCard({super.key, required this.space, required this.memberCount, this.memberNames, this.isDefault = false, this.showDefaultToggle = false, required this.onTap, required this.onToggleDefault});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final isSplit = space.mode == SpaceMode.split;
    final modeColor = isSplit ? AppColors.primary : AppColors.positive;
    final modeLabel = isSplit ? l10n.splitMode : l10n.personalMode;
    final modeIcon = isSplit ? Icons.groups_outlined : Icons.person_outline;
    final names = memberNames;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: BorderRadius.circular(AppRadius.xl),
      color: p.surface,
      child: Row(
        children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(gradient: AppGradients.tint(modeColor, alpha: 0.18), borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(modeIcon, size: 23, color: modeColor)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(space.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleS.copyWith(color: p.textPrimary)),
              const SizedBox(height: 5),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: modeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(modeIcon, size: 12, color: modeColor), const SizedBox(width: 4), Text(modeLabel, style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: modeColor))])),
                if (memberCount != null) ...[const SizedBox(width: AppSpacing.sm), Flexible(child: Text(l10n.spaceMembersCount(memberCount!), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: p.textSecondary)))],
              ]),
            ]),
          ),
          if (names != null && names.isNotEmpty) ...[const SizedBox(width: AppSpacing.sm), _MemberAvatarBadge(names: names)],
          if (showDefaultToggle) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(key: ValueKey('default_toggle_${space.id}'), tooltip: l10n.openByDefault, onPressed: onToggleDefault, visualDensity: VisualDensity.compact, icon: Icon(isDefault ? Icons.star_rounded : Icons.star_border_rounded, size: 24, color: isDefault ? Colors.amber.shade600 : p.textMuted)),
            const SizedBox(width: 2),
          ],
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, size: 26, color: p.textMuted),
        ],
      ),
    );
  }
}

class _MemberAvatarBadge extends StatelessWidget {
  final List<String> names;
  const _MemberAvatarBadge({required this.names});
  @override
  Widget build(BuildContext context) {
    const size = 20.0;
    const max = 3;
    final visible = names.length.clamp(0, max);
    final overflow = names.length - visible;
    final width = (visible <= 0 ? 0.0 : (visible - 1) * (size * 0.62) + size) + (overflow > 0 ? size * 0.62 : 0.0);
    return SizedBox(width: width, child: AvatarStack(names: names, size: size, max: max));
  }
}

class _SpaceActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _SpaceActionButton({super.key, required this.icon, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.negative,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(onTap: onPressed, child: SizedBox(width: double.infinity, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 22), const SizedBox(height: AppSpacing.xs), Text(label, style: AppText.overline.copyWith(color: Colors.white))]))),
    );
  }
}

class _PendingSpaceCard extends StatelessWidget {
  final Space space;
  const _PendingSpaceCard({required this.space});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return Container(
      key: ValueKey('pending_space_${space.id}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(gradient: AppGradients.tint(AppColors.primary, alpha: 0.06), borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primary.withValues(alpha: 0.25))),
      child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(gradient: AppGradients.tint(AppColors.primary, alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.md)), child: const Icon(Icons.hourglass_top_rounded, size: 24, color: AppColors.primary)),
        const SizedBox(width: AppSpacing.md + 2),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(space.name, style: AppText.titleM.copyWith(color: p.textPrimary)), const SizedBox(height: AppSpacing.xs), Text(l10n.pendingApproval, style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary))])),
        Icon(Icons.lock_outline_rounded, size: 20, color: p.textMuted),
      ]),
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
    return EmptyState(icon: Icons.workspaces_outline, title: l10n.noSpacesYet, message: l10n.noSpacesMessage, action: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl), child: Column(children: [PrimaryButton(label: l10n.createSpace, icon: Icons.add_rounded, onPressed: onCreate), const SizedBox(height: AppSpacing.md), SecondaryButton(label: l10n.joinSpace, icon: Icons.group_add_outlined, onPressed: onJoin)])));
  }
}
