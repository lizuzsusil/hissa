import 'package:flutter/material.dart';

/// Central design tokens for Hissa.
///
/// The palette pairs a calm, paper-like neutral ramp with a confident ocean
/// blue brand, a warm amber accent reserved for money actions, and restrained
/// semantic greens/reds. Colour is used to communicate meaning — never as
/// decoration.
abstract final class AppColors {
  // Brand — ocean blue.
  static const Color primary = Color(0xFF1373A8);
  static const Color primaryDeep = Color(0xFF0A4A70);
  static const Color primaryBright = Color(0xFF45A8D8);

  // Brand — warm amber accent (money/settle actions).
  static const Color secondary = Color(0xFFED6A1C);
  static const Color secondaryDark = Color(0xFFC85410);
  static const Color secondarySoft = Color(0xFFFDEDE1);

  // Supporting hues.
  static const Color accent = Color(0xFFF5A623);
  static const Color tertiary = Color(0xFF7C5CE0);
  static const Color tertiarySoft = Color(0xFFEFEBFC);
  static const Color info = Color(0xFF3D9BE9);
  static const Color infoSoft = Color(0xFFE8F3FC);

  // Semantic.
  static const Color positive = Color(0xFF17915A);
  static const Color positiveSoft = Color(0xFFE2F5EA);
  static const Color negative = Color(0xFFD93A40);
  static const Color negativeSoft = Color(0xFFFBE9EA);
  static const Color warning = Color(0xFFE89413);
  static const Color warningSoft = Color(0xFFFCF2DF);

  // Legacy gradient stops kept for chart compatibility.
  static const Color primaryDark = primaryDeep;
  static const Color gradientTop = Color(0xFF2C95CB);
  static const Color gradientBottom = Color(0xFF0B587F);

  /// Hero surfaces: the only saturated gradient in the product, used for the
  /// dashboard header and summary statements.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientTop, primary, gradientBottom],
  );

  /// Calm depth gradient for primary controls (buttons, FAB, active nav
  /// pill). Both stops keep ≥4.5:1 contrast with white labels so text stays
  /// readable across the entire fill.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF0D547F)],
  );

  /// Depth gradient for destructive controls, mirroring [primaryGradient].
  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE14B51), Color(0xFFC22E34)],
  );

  /// Subtle sheen for loading placeholders.
  static const LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5FB6E2), Color(0xFF1E86BE), Color(0xFF0B5E93)],
  );

  // Surfaces & neutrals (light) — mirrored from [AppPalette.light] so both
  // token systems stay in sync. New code should prefer context.palette.
  static const Color bg = _LightTokens.bg;
  static const Color surface = _LightTokens.surface;
  static const Color surfaceAlt = _LightTokens.surfaceAlt;
  static const Color border = _LightTokens.border;
  static const Color borderStrong = _LightTokens.borderStrong;
  static const Color textPrimary = _LightTokens.textPrimary;
  static const Color textSecondary = _LightTokens.textSecondary;
  static const Color textMuted = _LightTokens.textMuted;

  // Surfaces & neutrals (dark).
  static const Color bgDark = _DarkTokens.bg;
  static const Color surfaceDark = _DarkTokens.surface;
  static const Color surfaceAltDark = _DarkTokens.surfaceAlt;
  static const Color borderDark = _DarkTokens.border;
  static const Color textPrimaryDark = _DarkTokens.textPrimary;
  static const Color textSecondaryDark = _DarkTokens.textSecondary;
  static const Color textMutedDark = _DarkTokens.textMuted;

  /// Ink used on top of the hero gradient / dark toast surfaces in both modes.
  static const Color onHeroMuted = Color(0xCCFFFFFF);
}

/// Reusable gradients. Restrained by design: hero stays blue; tint() builds
/// soft icon-well fills from any hue; charts cycle through a curated set.
abstract final class AppGradients {
  /// Warm amber-orange for money/settle emphasis.
  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF07E33), Color(0xFFDD5B12)],
  );

  /// Emerald for settled/positive moments.
  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2FAF76), Color(0xFF128552)],
  );

  /// Sky blue for info surfaces.
  static const LinearGradient info = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF63C4F5), Color(0xFF1E88D4)],
  );

  /// Violet for premium summary cards.
  static const LinearGradient violet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B7EF0), Color(0xFF6C4FCB)],
  );

  /// Amber for highlights.
  static const LinearGradient warning = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8CC4A), Color(0xFFF2A900)],
  );

  /// Cycling palette for bar charts so each bucket reads distinctly.
  static const List<LinearGradient> barChart = [
    AppColors.heroGradient,
    accent,
    success,
    violet,
    info,
    warning,
  ];

  /// Soft diagonal fill from a solid [color] for tinted icon wells.
  static LinearGradient tint(Color color, {double alpha = 0.14}) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.45),
        ],
      );
}

/// Raw neutral hex values shared by [AppPalette] and the legacy
/// [AppColors] aliases so they can never drift apart.
abstract final class _LightTokens {
  static const Color bg = Color(0xFFF4F5F7);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFEFF1F4);
  static const Color border = Color(0xFFE4E7EC);
  static const Color borderStrong = Color(0xFFCFD5DF);
  static const Color textPrimary = Color(0xFF171B22);
  static const Color textSecondary = Color(0xFF4D5560);
  static const Color textMuted = Color(0xFF878FA0);
  static const Color skeletonBase = Color(0xFFE9ECF1);
  static const Color skeletonHighlight = Color(0xFFF7F8FA);
}

abstract final class _DarkTokens {
  static const Color bg = Color(0xFF0B0D11);
  static const Color surface = Color(0xFF14171C);
  static const Color surfaceAlt = Color(0xFF1D222B);
  static const Color border = Color(0xFF272D38);
  static const Color borderStrong = Color(0xFF39414F);
  static const Color textPrimary = Color(0xFFF1F3F6);
  static const Color textSecondary = Color(0xFFA8AFBC);
  static const Color textMuted = Color(0xFF69727F);
  static const Color skeletonBase = Color(0xFF232935);
  static const Color skeletonHighlight = Color(0xFF2C3442);
}

/// Brightness-resolved neutral tokens. Access via `context.palette` so
/// widgets never hand-roll `isDark ? x : y` ternaries.
class AppPalette {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color skeletonBase;
  final Color skeletonHighlight;

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  static const AppPalette light = AppPalette(
    bg: _LightTokens.bg,
    surface: _LightTokens.surface,
    surfaceAlt: _LightTokens.surfaceAlt,
    border: _LightTokens.border,
    borderStrong: _LightTokens.borderStrong,
    textPrimary: _LightTokens.textPrimary,
    textSecondary: _LightTokens.textSecondary,
    textMuted: _LightTokens.textMuted,
    skeletonBase: _LightTokens.skeletonBase,
    skeletonHighlight: _LightTokens.skeletonHighlight,
  );

  static const AppPalette dark = AppPalette(
    bg: _DarkTokens.bg,
    surface: _DarkTokens.surface,
    surfaceAlt: _DarkTokens.surfaceAlt,
    border: _DarkTokens.border,
    borderStrong: _DarkTokens.borderStrong,
    textPrimary: _DarkTokens.textPrimary,
    textSecondary: _DarkTokens.textSecondary,
    textMuted: _DarkTokens.textMuted,
    skeletonBase: _DarkTokens.skeletonBase,
    skeletonHighlight: _DarkTokens.skeletonHighlight,
  );
}

extension HissaBuildContextX on BuildContext {
  /// True when the ambient theme is dark.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Brightness-resolved neutral tokens (surfaces, borders, text).
  AppPalette get palette =>
      isDark ? AppPalette.dark : AppPalette.light;
}
