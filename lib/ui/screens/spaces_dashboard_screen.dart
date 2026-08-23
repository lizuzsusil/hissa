import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../widgets/spaces_view.dart';

/// Post-login landing screen. Full-screen dashboard with header + sign-out.
/// For the Settings-embedded version see `SettingsSpacesScreen`.
class SpacesDashboardScreen extends StatelessWidget {
  final ValueChanged<Space> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onSignOut;

  const SpacesDashboardScreen({
    super.key,
    required this.onSelect,
    required this.onCreate,
    required this.onJoin,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SpacesView(
          showSignOut: true,
          onSelect: onSelect,
          onCreate: onCreate,
          onJoin: onJoin,
          onSignOut: onSignOut,
        ),
      ),
    );
  }
}
