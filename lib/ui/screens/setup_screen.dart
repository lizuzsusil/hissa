import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/toasts.dart';

class SetupScreen extends StatefulWidget {
  final VoidCallback onDone;

  /// Whether the screen starts in create mode (true) or join mode (false).
  final bool initialCreateMode;

  /// Invoked when the user navigates back to the Spaces dashboard. When null,
  /// no back button is shown.
  final VoidCallback? onBack;

  const SetupScreen({
    super.key,
    required this.onDone,
    this.initialCreateMode = true,
    this.onBack,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late bool _createMode = widget.initialCreateMode;
  bool _loading = false;

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _memberController = TextEditingController();
  final _nameFocus = FocusNode();

  /// Emails of the people to invite when creating the Space.
  final List<String> _members = [];

  SpaceMode _mode = SpaceMode.split;
  CycleType _cycleType = CycleType.monthly;
  String? _nameError;
  String? _codeError;
  String? _memberError;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_handleNameFocus);
    if (!widget.initialCreateMode) {
      // Re-entering the join screen shows any Space join requests that are
      // still awaiting the owner's approval.
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPending());
    }
  }

  /// Re-queries the user's pending join requests. When any of them has been
  /// approved since the last refresh, the user is dropped straight into their
  /// new Space (they are now a member). Otherwise the pending list is updated
  /// in place so the requester stays in a visible pending state.
  Future<void> _refreshPending() async {
    final state = context.read<AppState>();
    final approved = await state.refreshPendingSpaceJoinRequests();
    if (!mounted || approved.isEmpty) return;
    await state.selectSpace(approved.first.id);
    if (!mounted) return;
    widget.onDone();
  }

  void _handleNameFocus() {
    if (_nameFocus.hasFocus) return;
    setState(() {
      _nameError = _nameController.text.trim().isEmpty
          ? context.l10n.spaceNameRequired
          : null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _memberController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final vm = ValidatorMessages.fromL10n(context.l10n);
    final error = validateName(
      _nameController.text,
      label: context.l10n.spaceName,
      messages: vm,
    );
    if (error != null) {
      setState(() => _nameError = error);
      return;
    }
    setState(() => _loading = true);
    final state = context.read<AppState>();
    await state.createSpace(
      name: _nameController.text,
      currency: kDefaultCurrency,
      memberEmails: _members,
      mode: _mode,
      cycleType: _cycleType,
    );
    if (mounted) {
      setState(() => _loading = false);
      widget.onDone();
    }
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    final vm = ValidatorMessages.fromL10n(context.l10n);
    final error = validateInviteCode(code, messages: vm);
    if (error != null) {
      setState(() => _codeError = error);
      return;
    }
    setState(() => _loading = true);
    final state = context.read<AppState>();
    final outcome = await state.requestSpaceJoin(code);
    if (!mounted) return;
    setState(() => _loading = false);
    switch (outcome) {
      case SpaceJoinOutcome.spaceNotFound:
        showToast(context, context.l10n.inviteNotFound, type: ToastType.danger);
      case SpaceJoinOutcome.alreadyMember:
        widget.onDone();
      case SpaceJoinOutcome.requestPending:
      case SpaceJoinOutcome.requestCreated:
        // The requester is kept in a pending state: every Space they requested
        // stays visible until the owner approves or rejects it. Re-fetch the
        // list so the newly submitted request appears immediately.
        _codeController.clear();
        await _refreshPending();
    }
  }

  void _addMember() {
    final email = _memberController.text.trim();
    final vm = ValidatorMessages.fromL10n(context.l10n);
    final error = validateEmail(email, messages: vm);
    if (error != null) {
      setState(() => _memberError = error);
      return;
    }
    final normalized = email.toLowerCase();
    if (_members.any((e) => e.toLowerCase() == normalized)) {
      setState(() => _memberError = context.l10n.duplicateEmailError);
      return;
    }
    setState(() {
      _members.add(normalized);
      _memberError = null;
      _memberController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshPending,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.onBack != null) ...[
                      IconAction(
                        icon: Icons.arrow_back_rounded,
                        size: 46,
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        _createMode ? l10n.createSpaceTitle : l10n.joinSpace,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _createMode ? l10n.createSpaceSubtitle : l10n.setUpSubtitle,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                _Segmented(
                  options: [l10n.create, l10n.join],
                  index: _createMode ? 0 : 1,
                  onChanged: _loading
                      ? null
                      : (i) => setState(() => _createMode = i == 0),
                ),
                const SizedBox(height: 28),
                if (_createMode) _buildCreate(isDark) else _buildJoin(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreate(bool isDark) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          focusNode: _nameFocus,
          enabled: !_loading,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.spaceName,
            hintText: l10n.spaceNameHint,
            prefixIcon: const Icon(Icons.workspaces_outline, size: 18),
            errorText: _nameError,
          ),
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        const SizedBox(height: 20),
        Text(
          l10n.chooseSpaceMode,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ModeCard(
                icon: Icons.groups_outlined,
                title: l10n.splitMode,
                subtitle: l10n.splitModeDescription,
                selected: _mode == SpaceMode.split,
                onTap: _loading
                    ? null
                    : () => setState(() => _mode = SpaceMode.split),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeCard(
                icon: Icons.person_outline,
                title: l10n.personalMode,
                subtitle: l10n.personalModeDescription,
                selected: _mode == SpaceMode.personal,
                onTap: _loading
                    ? null
                    : () => setState(() => _mode = SpaceMode.personal),
              ),
            ),
          ],
        ),
        if (_mode == SpaceMode.split) ...[
          const SizedBox(height: 18),
          Text(
            l10n.chooseCycleType,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ModeCard(
                  key: const ValueKey('cycle_monthly'),
                  icon: Icons.calendar_month_outlined,
                  title: l10n.monthlyCycle,
                  subtitle: l10n.monthlyCycleDescription,
                  selected: _cycleType == CycleType.monthly,
                  onTap: _loading
                      ? null
                      : () => setState(() => _cycleType = CycleType.monthly),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeCard(
                  key: const ValueKey('cycle_custom'),
                  icon: Icons.tune_outlined,
                  title: l10n.customCycle,
                  subtitle: l10n.customCycleDescription,
                  selected: _cycleType == CycleType.custom,
                  onTap: _loading
                      ? null
                      : () => setState(() => _cycleType = CycleType.custom),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            l10n.whoLivesHere,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (_members.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final email in _members)
                  Chip(
                    avatar: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: Text(email),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: _loading
                        ? null
                        : () => setState(() => _members.remove(email)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _memberController,
                  enabled: !_loading,
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
                  onSubmitted: (_) => _addMember(),
                ),
              ),
              const SizedBox(width: 10),
              IconAction(
                icon: Icons.add_rounded,
                background: AppColors.primary,
                foreground: Colors.white,
                size: 50,
                onPressed: _loading ? null : _addMember,
              ),
            ],
          ),
        ],
        const SizedBox(height: 28),
        PrimaryButton(
          label: l10n.createSpace,
          icon: Icons.check_circle_outline_rounded,
          loading: _loading,
          onPressed: _loading ? null : _create,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            l10n.inviteLater,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJoin(bool isDark) {
    final l10n = context.l10n;
    final state = context.watch<AppState>();
    final pending = state.myPendingSpaceJoinRequests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Every Space the user requested stays visible until the owner
        // approves or rejects it. The code input stays available so the user
        // can request multiple Spaces at once.
        if (pending.isNotEmpty) ...[
          for (final request in pending) ...[
            _PendingJoinCard(
              spaceName: state.spaceNameById(request.spaceId) ?? '',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          Text(
            l10n.joinRequestPendingDescription,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
        ],
        TextField(
          controller: _codeController,
          enabled: !_loading,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 6,
          ),
          decoration: InputDecoration(
            labelText: l10n.inviteCode,
            hintText: l10n.inviteCodeHint,
            prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
            errorText: _codeError,
          ),
          onChanged: (_) {
            if (_codeError != null) setState(() => _codeError = null);
          },
        ),
        const SizedBox(height: 12),
        Text(
          l10n.inviteCodeHelp,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: l10n.joinSpace,
          icon: Icons.group_add_outlined,
          loading: _loading,
          onPressed: _loading ? null : _join,
        ),
      ],
    );
  }
}

/// A pending Space join request card: the requested Space's name plus a
/// "pending approval" status. Shown on the join screen so the requester keeps
/// seeing every unresolved request until the owner decides.
class _PendingJoinCard extends StatelessWidget {
  final String spaceName;
  final bool isDark;

  const _PendingJoinCard({required this.spaceName, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: AppColors.primary,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spaceName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
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
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = selected
        ? AppColors.primary
        : (isDark ? AppColors.borderDark : AppColors.border);
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : (isDark ? AppColors.surfaceDark : Colors.white),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: selected ? 1.8 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 20,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final List<String> options;
  final int index;
  final ValueChanged<int>? onChanged;

  const _Segmented({
    required this.options,
    required this.index,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: index * width,
                width: width,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < options.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: onChanged == null ? null : () => onChanged!(i),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Text(
                            options[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: i == index
                                  ? AppColors.primary
                                  : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
