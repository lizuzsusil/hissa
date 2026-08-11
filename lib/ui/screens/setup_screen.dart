import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/avatars.dart';

class SetupScreen extends StatefulWidget {
  final VoidCallback onDone;

  const SetupScreen({super.key, required this.onDone});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _createMode = true;
  bool _loading = false;

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _memberController = TextEditingController();
  final List<String> _members = [];
  String _currency = kDefaultCurrency;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    final state = context.read<AppState>();
    await state.createHousehold(
      name: _nameController.text,
      currency: _currency,
      memberNames: _members,
    );
    if (mounted) {
      setState(() => _loading = false);
      widget.onDone();
    }
  }

  Future<void> _join() async {
    setState(() => _loading = true);
    final state = context.read<AppState>();
    final ok = await state.joinHousehold(_codeController.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      _toast('Invite code not found. Check the code and try again.');
      return;
    }
    widget.onDone();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isEmpty || _members.contains(name)) {
      _memberController.clear();
      return;
    }
    setState(() => _members.add(name));
    _memberController.clear();
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 12),
              Text(
                'Set up your household',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a new household or join one with an invite code.',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              _Segmented(
                options: const ['Create', 'Join'],
                index: _createMode ? 0 : 1,
                onChanged: (i) => setState(() => _createMode = i == 0),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Household name',
            hintText: 'e.g. Our Home',
            suffixIcon: Icon(Icons.home_outlined, size: 18),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Who lives here?',
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
                  onDeleted: () => setState(() => _members.remove(name)),
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
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Add a member',
                  hintText: 'Name',
                  suffixIcon: Icon(Icons.person_add_alt_1_outlined, size: 18),
                ),
                onSubmitted: (_) => _addMember(),
              ),
            ),
            const SizedBox(width: 10),
            IconAction(
              icon: Icons.add_rounded,
              background: AppColors.primary,
              foreground: Colors.white,
              size: 50,
              onPressed: _addMember,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Currency',
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
          onChanged: (v) => setState(() => _currency = v ?? kDefaultCurrency),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Create household',
          icon: Icons.check_circle_outline_rounded,
          loading: _loading,
          onPressed: _loading
              ? null
              : (_nameController.text.trim().isEmpty ? null : _create),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'You can invite more people later from Settings',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 6,
          ),
          decoration: const InputDecoration(
            labelText: 'Invite code',
            hintText: 'SUNNY9',
            suffixIcon: Icon(Icons.vpn_key_outlined, size: 18),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ask the household owner for their invite code. Codes are shown in Settings → Household.',
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
          label: 'Join household',
          icon: Icons.group_add_outlined,
          loading: _loading,
          onPressed: _loading ? null : _join,
        ),
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  const _Segmented({
    required this.options,
    required this.index,
    required this.onChanged,
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
                onTap: () => onChanged(i),
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
