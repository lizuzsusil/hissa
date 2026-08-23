import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';

class IntroScreen extends StatelessWidget {
  /// Called with the selected mode when the user confirms their choice.
  final void Function(String mode) onContinue;

  const IntroScreen({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return _IntroScreenContent(onContinue: onContinue);
  }
}

class _IntroScreenContent extends StatefulWidget {
  final void Function(String mode) onContinue;

  const _IntroScreenContent({required this.onContinue});

  @override
  State<_IntroScreenContent> createState() => _IntroScreenContentState();
}

class _IntroScreenContentState extends State<_IntroScreenContent> {
  String? _selectedMode;

  void _continue() {
    final mode = _selectedMode;
    if (mode == null) return;
    widget.onContinue(mode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxxl - 8),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Hissa',
                    style: AppText.displayM.copyWith(
                      fontSize: 22,
                      letterSpacing: -0.3,
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl + AppSpacing.lg),
              Text(
                l10n.onboardingTitle,
                style: AppText.displayL.copyWith(
                  height: 1.15,
                  letterSpacing: -0.8,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.onboardingSubtitle,
                style: AppText.bodyL.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Expanded(
                child: ListView.separated(
                  itemCount: kOnboardingModes.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final mode = kOnboardingModes[index];
                    final selected = _selectedMode == mode.title;
                    return _ModeCard(
                      mode: mode,
                      selected: selected,
                      onTap: () => setState(() => _selectedMode = mode.title),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: l10n.continueLabel,
                icon: Icons.arrow_forward_rounded,
                onPressed: _selectedMode == null ? null : _continue,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final ModePreset mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    late final String title;
    late final String subtitle;
    switch (mode.title) {
      case 'Two People':
        title = l10n.modeTwoPeople;
        subtitle = l10n.modeTwoPeopleSubtitle;
      case 'Family':
        title = l10n.modeFamily;
        subtitle = l10n.modeFamilySubtitle;
      case 'Roommates':
        title = l10n.modeRoommates;
        subtitle = l10n.modeRoommatesSubtitle;
      case 'Other':
        title = l10n.modeOther;
        subtitle = l10n.modeOtherSubtitle;
      default:
        title = mode.title;
        subtitle = mode.subtitle;
    }
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.ease,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: SurfaceCard(
        onTap: onTap,
        border: !selected,
        padding: const EdgeInsets.all(AppSpacing.lg + 2),
        color: selected ? AppColors.primary.withValues(alpha: 0.06) : null,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : null,
                gradient:
                    selected ? null : AppGradients.tint(AppColors.primary),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                mode.icon,
                color: selected ? Colors.white : AppColors.primary,
                size: 25,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.titleM.copyWith(color: p.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppText.bodyM.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : p.borderStrong.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
