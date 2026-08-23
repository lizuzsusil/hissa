import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/spaces_view.dart';
import 'setup_screen.dart';

/// Settings-embedded My Spaces. Same core list as the login dashboard
/// (`SpacesView`) but with a standard Settings `AppBar` so header navigation
/// stays consistent inside the tab. No root-step switch — stays inside
/// `ShellScreen`'s Navigator.
class SettingsSpacesScreen extends StatelessWidget {
  const SettingsSpacesScreen({super.key});

  void _selectSpace(BuildContext context, Space space) async {
    await context.read<AppState>().selectSpace(space.id);
    if (!context.mounted) return;
    // Pop back to Settings; Shell will show the newly selected space.
    Navigator.of(context).pop();
  }

  void _openSetup(BuildContext context, {required bool create}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetupScreen(
          initialCreateMode: create,
          onDone: () {
            // SetupScreen's onDone expects to close itself; when pushed from
            // settings we just pop the setup route and then the spaces route
            // will refresh via AppState listeners.
            Navigator.of(context).pop();
          },
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mySpaces)),
      body: SafeArea(
        child: SpacesView(
          // No header sign-out here — Settings already has a dedicated Sign out tile.
          showSignOut: false,
          onSelect: (space) => _selectSpace(context, space),
          onCreate: () => _openSetup(context, create: true),
          onJoin: () => _openSetup(context, create: false),
        ),
      ),
    );
  }
}
