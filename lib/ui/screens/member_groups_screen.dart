import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ids.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/buttons.dart'
    show PrimaryButton;
import '../widgets/misc.dart'
    show SectionHeader;
import '../widgets/misc.dart';
import '../widgets/toasts.dart';

class MemberGroupsScreen extends StatelessWidget {
  const MemberGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final currentSpaceId = state.space?.id;

    final groups = state.repo.memberGroups
        .where((g) => g.spaceId == currentSpaceId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final activeGroups = groups.where((g) => g.isActive).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.memberGroups)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (activeGroups.isEmpty) ...[
            _EmptyState(onCreate: () => _openCreateGroupSheet(context, state)),
          ] else ...[
            for (final group in activeGroups)
              _GroupCard(group: group, state: state, isDark: isDark),
            const SizedBox(height: 20),
            PrimaryButton(
              label: l10n.createGroup,
              icon: Icons.add_rounded,
              onPressed: () => _openCreateGroupSheet(context, state),
            ),
          ],
        ],
      ),
    );
  }

  void _openCreateGroupSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => CreateGroupSheet(spaceId: state.space?.id ?? ''),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.groups_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.noMemberGroups,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l10n.noMemberGroupsDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.createGroup,
            icon: Icons.add_rounded,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final MemberGroup group;
  final AppState state;
  final bool isDark;

  const _GroupCard({
    required this.group,
    required this.state,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = group.ownerUserId == state.currentUserId;
    final ownerName = state.memberName(group.ownerUserId) ?? 'Unknown';
    final memberIds = state.repo.memberGroupMembers
        .where((m) => m.groupId == group.id)
        .map((m) => m.userId)
        .toList();
    final memberNames = memberIds.map((id) => state.memberName(id) ?? 'Unknown').toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _openGroupDetail(context),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MemberAvatar(name: ownerName, size: 40, outline: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isOwner)
                            Text(
                              context.l10n.managedByYou,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            )
                          else
                            Text(
                              '${context.l10n.managedBy} $ownerName',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isOwner)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                      ),
                  ],
                ),
                if (memberNames.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in memberNames)
                        Chip(
                          avatar: MemberAvatar(name: name, size: 18),
                          label: Text(name, style: const TextStyle(fontSize: 12.5)),
                          backgroundColor: isDark
                              ? AppColors.surfaceAltDark
                              : AppColors.surfaceAlt,
                          side: BorderSide(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.border,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openGroupDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(group: group),
      ),
    );
  }
}

class CreateGroupSheet extends StatefulWidget {
  final String spaceId;

  const CreateGroupSheet({super.key, required this.spaceId});

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final _pickedMembers = <String>{};

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    final members = state.members
        .where((m) => m.userId != state.currentUserId)
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.createMemberGroup,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.createGroupDescription,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.groupOwner,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  MemberAvatar(
                    name: state.currentUser?.name ?? l10n.you,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.currentUser?.name ?? l10n.you,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l10n.youAreOwner,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.selectGroupMembers,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.noOtherMembersToAdd,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: members.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final m = members[i];
                    return CheckboxListTile(
                      value: _pickedMembers.contains(m.userId),
                      title: Text(m.name),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _pickedMembers.add(m.userId);
                        } else {
                          _pickedMembers.remove(m.userId);
                        }
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: l10n.createGroup,
              onPressed: _pickedMembers.isNotEmpty
                  ? () => _createGroup(context, state)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup(BuildContext context, AppState state) async {
    final l10n = context.l10n;
    final memberIds = _pickedMembers.toList();

    try {
      final groupId = 'g_${genId(8)}';
      final now = DateTime.now();

      // Create the group
      final group = MemberGroup(
        id: groupId,
        spaceId: widget.spaceId,
        ownerUserId: state.currentUserId!,
        name: '${state.currentUser?.name ?? l10n.you}\'s Group',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await state.repo.saveMemberGroup(group);

      // Add members
      for (final userId in memberIds) {
        await state.repo.addGroupMember(groupId, userId);
      }

      if (!context.mounted) return;
      Navigator.of(context).pop();
      showToast(context, l10n.groupCreated, type: ToastType.success);
    } catch (e) {
      if (!context.mounted) return;
      showToast(context, l10n.groupCreateFailed, type: ToastType.danger);
    }
  }
}

class GroupDetailScreen extends StatefulWidget {
  final MemberGroup group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late final List<String> _memberIds;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _loadMembers() {
    final state = context.read<AppState>();
    _memberIds = state.repo.memberGroupMembers
        .where((m) => m.groupId == widget.group.id)
        .map((m) => m.userId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isOwner = widget.group.ownerUserId == state.currentUserId;
    final ownerName = state.memberName(widget.group.ownerUserId) ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: isOwner
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmDelete(context),
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: (() {
          final widgets = <Widget>[
            _OwnerCard(
              ownerName: ownerName,
              isOwner: isOwner,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            SectionHeader(title: context.l10n.members),
          ];
          if (_memberIds.isEmpty) {
            widgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    context.l10n.noMembersInGroup,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            );
          } else {
            widgets.addAll(
              _memberIds.map(
                (id) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Chip(
                    avatar: MemberAvatar(
                      name: state.memberName(id) ?? 'Unknown',
                      size: 20,
                    ),
                    label: Text(state.memberName(id) ?? 'Unknown'),
                    backgroundColor: isDark
                        ? AppColors.surfaceAltDark
                        : AppColors.surfaceAlt,
                    side: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.border,
                    ),
                    deleteIcon: const Icon(Icons.close_rounded, size: 18),
                    onDeleted: isOwner
                        ? () => _confirmRemoveMember(context, id)
                        : null,
                    deleteButtonTooltipMessage:
                        isOwner ? context.l10n.removeMember : null,
                  ),
                ),
              ),
            );
          }
          if (isOwner) {
            widgets.addAll([
              const SizedBox(height: 24),
              PrimaryButton(
                label: context.l10n.addMember,
                icon: Icons.person_add_rounded,
                onPressed: () => _openAddMemberSheet(context, state),
              ),
            ]);
          }
          return widgets;
        })(),
      ),
    );
  }

  void _openAddMemberSheet(BuildContext context, AppState state) {
    final availableMembers = state.members
        .where((m) =>
            m.userId != widget.group.ownerUserId &&
            !_memberIds.contains(m.userId))
        .toList();

    if (availableMembers.isEmpty) {
      showToast(context, context.l10n.noMembersAvailableToAdd, type: ToastType.warning);
      return;
    }

    final picked = <String>{};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.addGroupMember,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: availableMembers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final m = availableMembers[i];
                      return CheckboxListTile(
                        value: picked.contains(m.userId),
                        title: Text(m.name),
                        onChanged: (v) => setSheetState(() {
                          if (v == true) {
                            picked.add(m.userId);
                          } else {
                            picked.remove(m.userId);
                          }
                        }),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: context.l10n.addMember,
                  onPressed: picked.isNotEmpty
                      ? () => _addMembers(context, state, picked.toList())
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addMembers(BuildContext context, AppState state, List<String> memberIds) async {
    final l10n = context.l10n;
    try {
      for (final userId in memberIds) {
        await state.repo.addGroupMember(widget.group.id, userId);
      }
      if (!context.mounted) return;
      Navigator.of(context).pop();
      showToast(context, l10n.memberAdded, type: ToastType.success);
      _loadMembers();
      setState(() {});
    } catch (e) {
      if (!context.mounted) return;
      showToast(context, l10n.memberAddFailed, type: ToastType.danger);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteGroupTitle),
        content: Text(l10n.deleteGroupMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text(l10n.deleteGroup),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await context.read<AppState>().repo.deleteMemberGroup(widget.group.id);
        if (!context.mounted) return;
        Navigator.of(context).pop();
        showToast(context, l10n.groupDeleted, type: ToastType.success);
      } catch (e) {
        if (!context.mounted) return;
        showToast(context, l10n.groupDeleteFailed, type: ToastType.danger);
      }
    }
  }

  Future<void> _confirmRemoveMember(BuildContext context, String userId) async {
    final l10n = context.l10n;
    final name = context.read<AppState>().memberName(userId) ?? '?';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeGroupMemberTitle(name)),
        content: Text(l10n.removeGroupMemberMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text(l10n.removeMember),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await context.read<AppState>().repo.removeGroupMember(
              widget.group.id,
              userId,
            );
        if (!context.mounted) return;
        _loadMembers();
        setState(() {});
        showToast(context, l10n.memberRemoved, type: ToastType.success);
      } catch (e) {
        if (!context.mounted) return;
        showToast(context, l10n.memberRemoveFailed, type: ToastType.danger);
      }
    }
  }
}

class _OwnerCard extends StatelessWidget {
  final String ownerName;
  final bool isOwner;
  final bool isDark;

  const _OwnerCard({
    required this.ownerName,
    required this.isOwner,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isOwner ? AppColors.heroGradient : null,
        color: isOwner ? null : (isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt),
        borderRadius: BorderRadius.circular(20),
        border: isOwner ? null : Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      child: Row(
        children: [
          MemberAvatar(name: ownerName, size: 52, outline: isOwner),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOwner ? l10n.you : ownerName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isOwner ? Colors.white : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOwner ? l10n.groupOwner : l10n.groupOwnerLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isOwner
                        ? Colors.white.withValues(alpha: 0.8)
                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.managedByYou,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}