import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
          ? 'Enter your name'
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = _nameController.text.trim().isEmpty ? (user?.name ?? 'You') : _nameController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: MemberAvatar(name: name, size: 96, outline: true),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user?.email ?? '',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Display name',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              suffixIcon: const Icon(Icons.badge_outlined, size: 18),
              errorText: _nameError,
            ),
            onChanged: (_) {
              setState(() {
                if (_nameError != null) _nameError = null;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            'This name is shared with your household members.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Save changes',
            icon: Icons.save_rounded,
            loading: _saving,
            onPressed: _nameController.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}
