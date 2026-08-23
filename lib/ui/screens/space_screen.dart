import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/dialogs.dart';
import '../widgets/misc.dart';
import '../widgets/toasts.dart';
import 'member_groups_screen.dart';

class SpaceScreen extends StatefulWidget {
  const SpaceScreen({super.key});

  @override
  State<SpaceScreen> createState() => _SpaceScreenState();
}

class _SpaceScreenState extends State<SpaceScreen> {
  final _memberController = TextEditingController();
  String? _memberError;

  @override
  void dispose() {
    _memberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final space = state.space;
    final p = context.palette;
    final l10n = context.l10n;

    if (space == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.space)),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            HeroCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.home_work_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        l10n.space,
                        style: AppText.labelM.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    space.name,
                    style: AppText.displayM.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Text(
                    '${space.currency} · ${l10n.spaceMembersCount(state.members.length)}',
                    style: AppText.bodyM.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: l10n.inviteCode),
            Text(
              l10n.shareInviteHint,
              style: AppText.bodyM.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            SurfaceCard(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: p.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        space.inviteCode,
                        style: AppText.displayM.copyWith(
                          letterSpacing: 8,
                          fontFamily: 'monospace',
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  IconAction(
                    icon: Icons.copy_rounded,
                    background: AppColors.primary,
                    foreground: Colors.white,
                    tooltip: l10n.inviteCodeCopied,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: space.inviteCode));
                      showToast(
                        context,
                        l10n.inviteCodeCopied,
                        type: ToastType.success,
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconAction(
                    icon: Icons.share_rounded,
                    background: AppColors.secondary,
                    foreground: Colors.white,
                    tooltip: l10n.shareInviteCode,
                    onPressed: () => _shareInvite(context, space),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(child: SectionHeader(title: l10n.members)),
                Text(
                  l10n.spaceMembersCount(state.members.length),
                  style: AppText.labelL.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            for (final member in state.members)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _MemberRow(
                  member: member,
                  isYou: member.userId == state.currentUser?.id,
                  canRemove:
                      state.isOwner && member.userId != state.currentUser?.id,
                  onRemove: () => _confirmRemove(state, member),
                ),
              ),
            if (!state.isPersonalMode) ...[
              _MemberGroupsTile(onTap: () => _openMemberGroups(context)),
            ],
            if (state.isOwner && state.pendingSpaceJoinRequests.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: l10n.pendingJoinRequests),
              Text(
                l10n.pendingJoinRequestsDescription,
                style: AppText.bodyM.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final request in state.pendingSpaceJoinRequests)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _JoinRequestCard(
                    request: request,
                    onApprove: () => _approveJoin(state, request),
                    onReject: () => _rejectJoin(state, request),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.inviteMember,
                      hintText: l10n.inviteMemberHint,
                      prefixIcon: const Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 18,
                      ),
                      errorText: _memberError,
                    ),
                    onChanged: (_) {
                      if (_memberError != null) {
                        setState(() => _memberError = null);
                      }
                    },
                    onSubmitted: (_) => _inviteMember(state),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                IconAction(
                  icon: Icons.add_rounded,
                  background: AppColors.primary,
                  foreground: Colors.white,
                  size: 50,
                  onPressed: () => _inviteMember(state),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.inviteMemberHelper,
              style: AppText.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareInvite(BuildContext context, Space space) async {
    final l10n = context.l10n;
    final message = l10n.shareInviteMessage(space.name, space.inviteCode);
    try {
      await Share.share(message, subject: l10n.shareInviteSubject);
    } catch (_) {
      if (!context.mounted) return;
      showToast(context, l10n.inviteCodeCopied, type: ToastType.success);
    }
  }

  Future<void> _inviteMember(AppState state) async {
    final email = _memberController.text.trim();
    final vm = ValidatorMessages.fromL10n(context.l10n);
    final error = validateEmail(email, messages: vm);
    if (error != null) {
      setState(() => _memberError = error);
      return;
    }
    final invited = await state.inviteMember(email);
    if (!mounted) return;
    if (!invited) {
      setState(() => _memberError = context.l10n.inviteMemberAlreadyMember);
      return;
    }
    _memberController.clear();
    setState(() => _memberError = null);
    showToast(
      context,
      context.l10n.invitedMember(email),
      type: ToastType.success,
    );
  }

  Future<void> _approveJoin(AppState state, SpaceJoinRequest request) async {
    final l10n = context.l10n;
    try {
      await state.approveSpaceJoinRequest(request.id);
      if (!mounted) return;
      showToast(context, l10n.joinRequestApproved, type: ToastType.success);
    } catch (_) {
      if (!mounted) return;
      showToast(context, l10n.joinRequestApprovedFail, type: ToastType.danger);
    }
  }

  Future<void> _rejectJoin(AppState state, SpaceJoinRequest request) async {
    final l10n = context.l10n;
    try {
      await state.rejectSpaceJoinRequest(request.id);
      if (!mounted) return;
      showToast(context, l10n.joinRequestRejected, type: ToastType.warning);
    } catch (_) {
      if (!mounted) return;
      showToast(context, l10n.joinRequestRejectFail, type: ToastType.danger);
    }
  }

  Future<void> _confirmRemove(AppState state, SpaceMember member) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.removeMemberTitle(member.name),
      message: l10n.removeMemberMessage,
      confirmLabel: l10n.delete,
      destructive: true,
      icon: Icons.person_remove_outlined,
    );
    if (confirmed) {
      await state.removeMember(member.userId);
    }
  }

  void _openMemberGroups(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MemberGroupsScreen()));
  }
}

BadgeTone _roleTone(MemberRole role) {
  switch (role) {
    case MemberRole.owner:
      return BadgeTone.brand;
    case MemberRole.admin:
      return BadgeTone.info;
    case MemberRole.member:
      return BadgeTone.neutral;
  }
}

class _MemberRow extends StatelessWidget {
  final SpaceMember member;
  final bool isYou;
  final bool canRemove;
  final VoidCallback onRemove;

  const _MemberRow({
    required this.member,
    required this.isYou,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          MemberAvatar(name: member.name, size: 44),
          const SizedBox(width: AppSpacing.lg - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.titleS.copyWith(fontSize: 15),
                      ),
                    ),
                    if (isYou) ...[
                      const SizedBox(width: 6),
                      StatusBadge(label: l10n.you),
                    ],
                    const SizedBox(width: 6),
                    StatusBadge(
                      label: _roleLabel(l10n, member.role),
                      tone: _roleTone(member.role),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.memberJoinedDate(
                    _roleLabel(l10n, member.role),
                    formatShortDate(member.joinedAt),
                  ),
                  style: AppText.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          if (canRemove) ...[
            const SizedBox(width: AppSpacing.sm),
            IconAction(
              icon: Icons.person_remove_outlined,
              size: 36,
              foreground: AppColors.negative,
              background: context.isDark
                  ? AppColors.negative.withValues(alpha: 0.16)
                  : AppColors.negativeSoft,
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

String _roleLabel(AppLocalizations l10n, MemberRole role) {
  switch (role) {
    case MemberRole.owner:
      return l10n.roleOwner;
    case MemberRole.admin:
      return l10n.roleAdmin;
    case MemberRole.member:
      return l10n.roleMember;
  }
}

/// A pending Space join request awaiting the owner's decision, shown in the
/// Space → Members section. Only the owner sees these and may approve/reject.
class _JoinRequestCard extends StatelessWidget {
  final SpaceJoinRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _JoinRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(name: request.requesterName, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.requesterName,
                      style: AppText.titleS.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.wantsToJoinSpace,
                      style: AppText.caption.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: l10n.pendingApproval, tone: BadgeTone.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlineButton(
                  label: l10n.reject,
                  icon: Icons.close_rounded,
                  foreground: AppColors.negative,
                  onPressed: onReject,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(l10n.approve),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.positive,
                    disabledBackgroundColor: AppColors.positive,
                  ),
                  onPressed: onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Entry point for the Member Groups feature, nested inside the Space →
/// Members section so group management lives next to the member list it
/// groups.
class _MemberGroupsTile extends StatelessWidget {
  final VoidCallback onTap;

  const _MemberGroupsTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppGradients.tint(AppColors.primary),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.groups_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.memberGroups,
                  style: AppText.titleS.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.memberGroupsSubtitle,
                  style: AppText.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
        ],
      ),
    );
  }
}
