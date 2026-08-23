import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatars.dart';
import '../widgets/buttons.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  final _nameFocus = FocusNode();
  bool _saving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _nameFocus.addListener(_handleNameFocus);
  }

  void _handleNameFocus() {
    if (_nameFocus.hasFocus) return;
    setState(() {
      _nameError = _nameController.text.trim().isEmpty
          ? context.l10n.enterNameError
          : null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AppState>().updateProfile(_nameController.text);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;
    final p = context.palette;
    final l10n = context.l10n;
    final name = _nameController.text.trim().isEmpty
        ? (user?.name ?? 'You')
        : _nameController.text.trim();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
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
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  MemberAvatar(
                    name: name,
                    avatarUrl: user?.avatarUrl,
                    size: 96,
                    outline: true,
                  ),
                  Positioned(
                    right: -4,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.bg,
                      ),
                      child: IconAction(
                        icon: Icons.camera_alt_outlined,
                        size: 36,
                        background: p.surfaceAlt,
                        foreground: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text(
                name,
                style: AppText.titleL.copyWith(color: p.textPrimary),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: Text(
                user?.email ?? '',
                style: AppText.caption.copyWith(color: p.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              l10n.displayName,
              style: AppText.labelM.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                errorText: _nameError,
              ),
              onChanged: (_) {
                setState(() {
                  if (_nameError != null) _nameError = null;
                });
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.displayNameHint,
              style: AppText.caption.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: l10n.saveChanges,
              icon: Icons.save_rounded,
              loading: _saving,
              onPressed: _nameController.text.trim().isEmpty ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
