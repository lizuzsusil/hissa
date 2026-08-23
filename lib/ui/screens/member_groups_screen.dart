import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ids.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/buttons.dart' show PrimaryButton;
import '../widgets/cards.dart';
import '../widgets/dialogs.dart';
import '../widgets/misc.dart';
import '../widgets/motion.dart';
import '../widgets/sheets.dart';
import '../widgets/toasts.dart';

class MemberGroupsScreen extends StatelessWidget {
  const MemberGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = context.l10n;
    final currentSpaceId = state.space?.id;

    // Only the Space owner can approve/reject requests. Non-owner members see
    // only their own pending request with its "pending approval" status.
    final isOwner = state.isOwner;

    // Rule 3 / Rule 11: groups need at least three members to be meaningful.
    final groupsApplicable = state.memberGroupsApplicable;

    final groups =
        state.repo.memberGroups
            .where((g) => g.spaceId == currentSpaceId)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final activeGroups = groups.where((g) => g.isActive).toList();

    // The owner can create groups only when the space is big enough, and only
    // one group of their own: the owner cannot belong to multiple groups.
    final ownerAlreadyGrouped = state.groupedUserIds.contains(
      state.currentUserId,
    );
    final canCreate = isOwner && groupsApplicable && !ownerAlreadyGrouped;

    // Non-owners can request a group for the owner to create (Rule 4).
    final canRequest = state.canRequestGroup;

    // Whether the current user has an unresolved request awaiting the owner's
    // decision (used to surface a clear "pending approval" status).
    final hasPendingRequest = state.pendingGroupRequests.any(
      (r) => r.requesterUserId == state.currentUserId,
    );

    // Pending requests are shown to the owner for review (Rule 5); non-owners
    // only see their own request, never other members'.
    final pendingRequests = isOwner
        ? state.pendingGroupRequests
        : state.pendingGroupRequests
              .where((r) => r.requesterUserId == state.currentUserId)
              .toList();

    // Empty-state copy keeps the previous precedence: availability first,
    // then role-based actions, then pending/already-grouped states.
    final String emptyMessage;
    if (!groupsApplicable) {
      emptyMessage = l10n.groupCreationUnavailable;
    } else if (canCreate) {
      emptyMessage = l10n.noMemberGroupsDescription;
    } else if (canRequest) {
      emptyMessage = l10n.requestGroupDescription;
    } else if (hasPendingRequest) {
      // The requester's group creation request is awaiting the owner's
      // decision (Rule 5), so the create/request actions are hidden.
      emptyMessage = l10n.yourGroupRequestPending;
    } else if (ownerAlreadyGrouped) {
      // The owner already belongs to a group, so they cannot create another.
      emptyMessage = l10n.alreadyInGroup;
    } else {
      emptyMessage = l10n.onlyOwnerCanCreateGroups;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.memberGroups)),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          children: [
            if (pendingRequests.isNotEmpty)
              _PendingRequestsSection(requests: pendingRequests, state: state),
            if (activeGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                child: EmptyState(
                  icon: Icons.groups_rounded,
                  title: l10n.noMemberGroups,
                  message: emptyMessage,
                  action: (canCreate || canRequest)
                      ? Column(
                          children: [
                            if (canCreate)
                              PrimaryButton(
                                label: l10n.createGroup,
                                icon: Icons.add_rounded,
                                onPressed: () =>
                                    _openCreateGroupSheet(context, state),
                              ),
                            if (canRequest) ...[
                              if (canCreate)
                                const SizedBox(height: AppSpacing.md),
                              PrimaryButton(
                                label: l10n.requestGroup,
                                icon: Icons.outbox_rounded,
                                onPressed: () =>
                                    _openRequestGroupSheet(context, state),
                              ),
                            ],
                          ],
                        )
                      : null,
                ),
              )
            else ...[
              for (final group in activeGroups)
                _GroupCard(group: group, state: state),
              if (canCreate) ...[
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: l10n.createGroup,
                  icon: Icons.add_rounded,
                  onPressed: () => _openCreateGroupSheet(context, state),
                ),
              ],
              if (canRequest) ...[
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: l10n.requestGroup,
                  icon: Icons.outbox_rounded,
                  onPressed: () => _openRequestGroupSheet(context, state),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _openCreateGroupSheet(BuildContext context, AppState state) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      title: context.l10n.createMemberGroup,
      builder: (_) => CreateGroupSheet(spaceId: state.space?.id ?? ''),
    );
  }

  void _openRequestGroupSheet(BuildContext context, AppState state) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      title: context.l10n.requestGroupTitle,
      builder: (_) => const RequestGroupSheet(),
    );
  }
}

class _PendingRequestsSection extends StatelessWidget {
  final List<GroupRequest> requests;
  final AppState state;

  const _PendingRequestsSection({required this.requests, required this.state});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final isOwner = state.isOwner;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.pendingGroupRequests),
          if (isOwner)
            Text(
              l10n.pendingGroupRequestsDescription,
              style: AppText.caption.copyWith(color: p.textSecondary),
            ),
          const SizedBox(height: AppSpacing.md),
          for (final request in requests) ...[
            _RequestCard(request: request, state: state),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final GroupRequest request;
  final AppState state;

  const _RequestCard({required this.request, required this.state});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = context.isDark;
    final l10n = context.l10n;
    final requesterName =
        state.memberName(request.requesterUserId) ?? 'Unknown';
    final memberNames = request.memberUserIds
        .map((id) => state.memberName(id) ?? 'Unknown')
        .toList();

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(name: requesterName, size: 40, outline: true),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requesterName,
                      style: AppText.bodyL.copyWith(
                        fontWeight: FontWeight.w800,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      '${l10n.requestedBy} · ${l10n.groupOwner}',
                      style: AppText.caption.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: l10n.pendingApproval, tone: BadgeTone.brand),
            ],
          ),
          if (memberNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final name in memberNames)
                  Chip(
                    avatar: MemberAvatar(name: name, size: 18),
                    label: Text(name),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          // Only the Space owner may approve or reject a request (Rule 5).
          // Non-owner members and the requester themselves see only the
          // "pending approval" status.
          if (state.isOwner)
            Row(
              children: [
                Expanded(
                  child: _ActionPill(
                    label: l10n.reject,
                    icon: Icons.close_rounded,
                    background: dark
                        ? AppColors.negative.withValues(alpha: 0.16)
                        : AppColors.negativeSoft,
                    foreground: AppColors.negative,
                    onTap: () => _reject(context, state),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _ActionPill(
                    label: l10n.approve,
                    icon: Icons.check_rounded,
                    background: AppColors.positive,
                    foreground: Colors.white,
                    onTap: () => _approve(context, state),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, AppState state) async {
    final l10n = context.l10n;
    try {
      final group = await state.approveGroupRequest(request.id);
      if (!context.mounted) return;
      showToast(
        context,
        group != null
            ? l10n.groupRequestApproved
            : l10n.groupRequestApprovedFail,
        type: group != null ? ToastType.success : ToastType.danger,
      );
    } catch (_) {
      if (!context.mounted) return;
      showToast(context, l10n.groupRequestApprovedFail, type: ToastType.danger);
    }
  }

  Future<void> _reject(BuildContext context, AppState state) async {
    final l10n = context.l10n;
    try {
      await state.rejectGroupRequest(request.id);
      if (!context.mounted) return;
      showToast(context, l10n.groupRequestRejected, type: ToastType.warning);
    } catch (_) {
      if (!context.mounted) return;
      showToast(context, l10n.groupRequestRejectFail, type: ToastType.danger);
    }
  }
}

/// Compact confirm/deny pill matching the settle screen's inline actions:
/// solid positive for approve, soft negative for reject, h>=40, radius sm.
class _ActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _ActionPill({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelM.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RequestGroupSheet extends StatefulWidget {
  const RequestGroupSheet({super.key});

  @override
  State<RequestGroupSheet> createState() => _RequestGroupSheetState();
}

class _RequestGroupSheetState extends State<RequestGroupSheet> {
  final _pickedMembers = <String>{};

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final p = context.palette;
    final l10n = context.l10n;

    final members = state.requestableGroupMembers;

    // A group can hold at most (space members - 1) users including the owner.
    // The owner is the requester, so at most (max - 1) others can be chosen.
    final maxOtherMembers = state.maxGroupMembers - 1;

    // The request flow is for non-owner members, so the group is created by
    // the Space owner (who approves the request), not by the current user.
    final spaceOwnerId =
        state.space?.createdBy ??
        state.members
            .where((m) => m.role == MemberRole.owner)
            .firstOrNull
            ?.userId;
    final spaceOwnerName =
        state.memberName(spaceOwnerId ?? '') ?? l10n.groupOwner;
    final isCurrentUserOwner =
        spaceOwnerId != null && spaceOwnerId == state.currentUserId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.requestGroupDescription,
            style: AppText.bodyM.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.groupOwner,
            style: AppText.labelM.copyWith(
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                MemberAvatar(
                  name: isCurrentUserOwner ? l10n.you : spaceOwnerName,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrentUserOwner ? l10n.you : spaceOwnerName,
                        style: AppText.titleS.copyWith(
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        isCurrentUserOwner
                            ? l10n.youAreOwner
                            : l10n.groupOwnerLabel,
                        style: AppText.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.selectGroupMembers,
            style: AppText.labelM.copyWith(
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                l10n.noMembersToRequest,
                style: AppText.bodyM.copyWith(color: p.textMuted),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: members.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (_, i) {
                  final m = members[i];
                  return _MemberCheckRow(
                    name: m.name,
                    checked: _pickedMembers.contains(m.userId),
                    onChanged: (checked) => setState(() {
                      // Rule: a group can hold at most (space members - 1)
                      // users including the requester/owner.
                      if (checked) {
                        if (_pickedMembers.length >= maxOtherMembers) return;
                        _pickedMembers.add(m.userId);
                      } else {
                        _pickedMembers.remove(m.userId);
                      }
                    }),
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.requestGroup,
            onPressed: _pickedMembers.isNotEmpty
                ? () => _submit(context, state)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context, AppState state) async {
    final l10n = context.l10n;
    if (state.hasPendingGroupRequest(state.currentUserId ?? '')) {
      if (!context.mounted) return;
      showToast(
        context,
        l10n.groupRequestAlreadyPending,
        type: ToastType.warning,
      );
      return;
    }
    try {
      final request = await state.requestGroup(_pickedMembers.toList());
      if (!context.mounted) return;
      if (request == null) {
        showToast(context, l10n.groupRequestFailed, type: ToastType.danger);
        return;
      }
      Navigator.of(context).pop();
      showToast(context, l10n.groupRequested, type: ToastType.success);
    } catch (_) {
      if (!context.mounted) return;
      showToast(context, l10n.groupRequestFailed, type: ToastType.danger);
    }
  }
}

class _GroupCard extends StatelessWidget {
  final MemberGroup group;
  final AppState state;

  const _GroupCard({required this.group, required this.state});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isOwner = group.ownerUserId == state.currentUserId;
    final ownerName = state.memberName(group.ownerUserId) ?? 'Unknown';
    final memberIds = state.repo.memberGroupMembers
        .where((m) => m.groupId == group.id)
        .map((m) => m.userId)
        .toList();
    final memberNames = memberIds
        .map((id) => state.memberName(id) ?? 'Unknown')
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SurfaceCard(
        onTap: () => _openGroupDetail(context),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MemberAvatar(name: ownerName, size: 40, outline: true),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: AppText.titleM.copyWith(
                          fontWeight: FontWeight.w800,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (isOwner)
                        Text(
                          context.l10n.managedByYou,
                          style: AppText.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        )
                      else
                        Text(
                          '${context.l10n.managedBy} $ownerName',
                          style: AppText.caption.copyWith(color: p.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (isOwner)
                  Icon(Icons.chevron_right_rounded, color: p.textMuted),
              ],
            ),
            if (memberNames.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final name in memberNames)
                    Chip(
                      avatar: MemberAvatar(name: name, size: 18),
                      label: Text(name),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openGroupDetail(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)));
  }
}

/// Shared checkbox row for the three member pickers in this file (request
/// sheet, create sheet, add-member sheet). Selection/cap logic stays with
/// the caller.
class _MemberCheckRow extends StatelessWidget {
  final String name;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _MemberCheckRow({
    required this.name,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: checked,
      title: Text(name),
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
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
    final p = context.palette;
    final l10n = context.l10n;

    // Rule 2: every user can belong to at most one group. Users already in an
    // active group cannot be added to a new one.
    final alreadyGrouped = state.groupedUserIds;
    final members = state.members
        .where((m) => m.userId != state.currentUserId)
        .where((m) => !alreadyGrouped.contains(m.userId))
        .toList();

    // A group can hold at most (space members - 1) users including the owner.
    // The owner creates the group, so at most (max - 1) others can be chosen.
    final maxOtherMembers = state.maxGroupMembers - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.createGroupDescription,
            style: AppText.bodyM.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.groupOwner,
            style: AppText.labelM.copyWith(
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                MemberAvatar(
                  name: state.currentUser?.name ?? l10n.you,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.currentUser?.name ?? l10n.you,
                        style: AppText.titleS.copyWith(
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        l10n.youAreOwner,
                        style: AppText.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.selectGroupMembers,
            style: AppText.labelM.copyWith(
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                l10n.noOtherMembersToAdd,
                style: AppText.bodyM.copyWith(color: p.textMuted),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: members.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (_, i) {
                  final m = members[i];
                  return _MemberCheckRow(
                    name: m.name,
                    checked: _pickedMembers.contains(m.userId),
                    onChanged: (checked) => setState(() {
                      // Rule: a group can hold at most (space members - 1)
                      // users including the owner.
                      if (checked) {
                        if (_pickedMembers.length >= maxOtherMembers) return;
                        _pickedMembers.add(m.userId);
                      } else {
                        _pickedMembers.remove(m.userId);
                      }
                    }),
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.createGroup,
            onPressed: _pickedMembers.isNotEmpty
                ? () => _createGroup(context, state)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _createGroup(BuildContext context, AppState state) async {
    final l10n = context.l10n;
    final memberIds = _pickedMembers.toList();

    // Rule 2: the owner themselves can belong to only one group, so they cannot
    // create a new group while already represented by an existing one.
    if (state.groupedUserIds.contains(state.currentUserId)) {
      if (!context.mounted) return;
      showToast(context, l10n.alreadyInGroup, type: ToastType.warning);
      return;
    }

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
    final p = context.palette;

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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        children: (() {
          final widgets = <Widget>[
            _OwnerCard(ownerName: ownerName, isOwner: isOwner),
            const SizedBox(height: AppSpacing.xxl),
            SectionHeader(title: context.l10n.members),
          ];
          if (_memberIds.isEmpty) {
            widgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Text(
                    context.l10n.noMembersInGroup,
                    style: AppText.bodyM.copyWith(color: p.textMuted),
                  ),
                ),
              ),
            );
          } else {
            widgets.addAll(
              _memberIds.map(
                (id) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Chip(
                    avatar: MemberAvatar(
                      name: state.memberName(id) ?? 'Unknown',
                      size: 20,
                    ),
                    label: Text(state.memberName(id) ?? 'Unknown'),
                    deleteIcon: const Icon(Icons.close_rounded, size: 18),
                    onDeleted: isOwner
                        ? () => _confirmRemoveMember(context, id)
                        : null,
                    deleteButtonTooltipMessage: isOwner
                        ? context.l10n.removeMember
                        : null,
                  ),
                ),
              ),
            );
          }
          if (isOwner) {
            widgets.addAll([
              const SizedBox(height: AppSpacing.xxl),
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
    // Rule 2: a user can belong to only one group, so exclude anyone already
    // represented by another active group.
    final alreadyGrouped = state.groupedUserIds;
    final availableMembers = state.members
        .where(
          (m) =>
              m.userId != widget.group.ownerUserId &&
              !_memberIds.contains(m.userId) &&
              !alreadyGrouped.contains(m.userId),
        )
        .toList();

    // Rule: a group can hold at most (space members - 1) users including the
    // owner. If the group is already at the cap, members must be removed
    // before any new member can be added.
    final slotsRemaining = state.groupMemberSlotsRemaining(_memberIds.length);
    if (slotsRemaining <= 0) {
      showToast(context, context.l10n.groupFull, type: ToastType.warning);
      return;
    }

    if (availableMembers.isEmpty) {
      showToast(
        context,
        context.l10n.noMembersAvailableToAdd,
        type: ToastType.warning,
      );
      return;
    }

    final picked = <String>{};
    showAppSheet(
      context: context,
      isScrollControlled: true,
      title: context.l10n.addGroupMember,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: availableMembers.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (_, i) {
                    final m = availableMembers[i];
                    return _MemberCheckRow(
                      name: m.name,
                      checked: picked.contains(m.userId),
                      onChanged: (checked) => setSheetState(() {
                        // Rule: a group can hold at most (space members - 1)
                        // users including the owner.
                        if (checked) {
                          if (picked.length >= slotsRemaining) return;
                          picked.add(m.userId);
                        } else {
                          picked.remove(m.userId);
                        }
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: sheetContext.l10n.addMember,
                onPressed: picked.isNotEmpty
                    ? () => _addMembers(sheetContext, state, picked.toList())
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addMembers(
    BuildContext context,
    AppState state,
    List<String> memberIds,
  ) async {
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
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteGroupTitle,
      message: l10n.deleteGroupMessage,
      confirmLabel: l10n.deleteGroup,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed && context.mounted) {
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
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.removeGroupMemberTitle(name),
      message: l10n.removeGroupMemberMessage,
      confirmLabel: l10n.removeMember,
      destructive: true,
      icon: Icons.person_remove_rounded,
    );
    if (confirmed && context.mounted) {
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

/// Owner summary card: hero gradient statement for the current user's own
/// group, quiet surface card when browsing someone else's.
class _OwnerCard extends StatelessWidget {
  final String ownerName;
  final bool isOwner;

  const _OwnerCard({required this.ownerName, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;

    final content = Row(
      children: [
        MemberAvatar(name: ownerName, size: 52, outline: isOwner),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOwner ? l10n.you : ownerName,
                style: AppText.titleL.copyWith(
                  color: isOwner ? Colors.white : p.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isOwner ? l10n.groupOwner : l10n.groupOwnerLabel,
                style: AppText.caption.copyWith(
                  color: isOwner ? AppColors.onHeroMuted : p.textSecondary,
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    l10n.managedByYou,
                    style: AppText.overline.copyWith(
                      letterSpacing: 0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (!isOwner) {
      return SurfaceCard(color: p.surfaceAlt, padding: const EdgeInsets.all(AppSpacing.xl), child: content);
    }
    return HeroCard(gradient: AppColors.heroGradient, child: content);
  }
}
