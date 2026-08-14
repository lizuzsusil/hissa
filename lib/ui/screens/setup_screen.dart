import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/avatars.dart';
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
  final List<String> _members = [];
  String _currency = kDefaultCurrency;
  SpaceMode _mode = SpaceMode.split;
  String? _nameError;
  String? _codeError;
  String? _memberError;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_handleNameFocus);
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
      currency: _currency,
      memberNames: _members,
      mode: _mode,
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
    final ok = await state.joinSpace(code);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      showToast(context, context.l10n.inviteNotFound, type: ToastType.danger);
      return;
    }
    widget.onDone();
  }

  void _addMember() {
    final name = _memberController.text.trim();
    final vm = ValidatorMessages.fromL10n(context.l10n);
    final error = validateMemberName(
      name,
      existing: _members.toSet(),
      messages: vm,
    );
    if (error != null) {
      setState(() => _memberError = error);
      return;
    }
    setState(() {
      _members.add(name);
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
        child: SingleChildScrollView(
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
            suffixIcon: const Icon(Icons.workspaces_outline, size: 18),
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
                for (final name in _members)
                  Chip(
                    avatar: MemberAvatar(name: name, size: 24),
                    label: Text(name),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: _loading
                        ? null
                        : () => setState(() => _members.remove(name)),
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
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.addMember,
                    hintText: l10n.name,
                    suffixIcon: const Icon(
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
        const SizedBox(height: 14),
        Text(
          l10n.currency,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _currency,
          decoration: const InputDecoration(
            suffixIcon: Icon(Icons.currency_rupee, size: 18),
          ),
          items: const [
            DropdownMenuItem(value: 'NPR', child: Text('NPR - Nepalese Rupee')),
            DropdownMenuItem(value: 'USD', child: Text('USD - US Dollar')),
            DropdownMenuItem(value: 'INR', child: Text('INR - Indian Rupee')),
            DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
          ],
          onChanged: _loading
              ? null
              : (v) => setState(() => _currency = v ?? kDefaultCurrency),
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            suffixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
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

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeCard({
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
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: onChanged == null ? null : () => onChanged!(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: i == index
                        ? (isDark ? AppColors.surfaceDark : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: i == index
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    options[i],
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
    );
  }
}
