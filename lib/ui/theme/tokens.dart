import 'package:flutter/material.dart';

/// Base spacing unit for the 4px grid used across the app.
const double kSpacingUnit = 4;

/// Design tokens for spacing, derived from a 4px base grid so every screen
/// shares one consistent rhythm.
class AppSpacing {
  AppSpacing._();

  static const double xs = kSpacingUnit; // 4
  static const double sm = kSpacingUnit * 2; // 8
  static const double md = kSpacingUnit * 3; // 12
  static const double lg = kSpacingUnit * 4; // 16
  static const double xl = kSpacingUnit * 5; // 20
  static const double xxl = kSpacingUnit * 7; // 28
  static const double xxxl = kSpacingUnit * 10; // 40

  /// Standard horizontal page gutter.
  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: xl);
}

/// Design tokens for corner radii.
///
/// - [sm] for tiny controls (badges, dots, small chips)
/// - [md] for interactive controls (buttons, inputs, chips)
/// - [lg] for cards and list containers
/// - [xl] for sheets, dialogs and hero surfaces
class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;

  static BorderRadius get rSm => BorderRadius.circular(sm);
  static BorderRadius get rMd => BorderRadius.circular(md);
  static BorderRadius get rLg => BorderRadius.circular(lg);
  static BorderRadius get rXl => BorderRadius.circular(xl);
}

/// Design tokens for motion. Durations are short and functional so
/// micro-interactions feel responsive rather than sluggish.
class AppMotion {
  AppMotion._();

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);

  /// The house curve for entrances and hover/focus transitions.
  static const Curve ease = Curves.easeOutCubic;

  /// Slightly springier curve for playful emphasis (nav pills, FAB).
  static const Curve emphasized = Curves.easeOutBack;
}

/// Centralized shadow/elevation system. Shadows are ambient (large blur,
/// low alpha) plus a tight contact layer — never harsh single drop shadows.
abstract final class AppShadows {
  /// Resting card shadow — barely-there lift so bordered cards feel tactile.
  static List<BoxShadow> card({required bool dark}) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.32 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Raised elements: FAB, popovers, active drag surfaces.
  static List<BoxShadow> raised({required bool dark}) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.45 : 0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  /// Floating overlays: dialogs, bottom sheets, toasts.
  static List<BoxShadow> overlay({required bool dark}) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.55 : 0.16),
          blurRadius: 36,
          offset: const Offset(0, 14),
        ),
      ];
}

/// Typography scale. Sizes/weights/tracking only — resolve color from the
/// ambient theme so text adapts to light/dark automatically.
abstract final class AppText {
  // Display — hero numbers & page statements.
  static const TextStyle displayL = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    height: 1.1,
  );
  static const TextStyle displayM = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.7,
    height: 1.15,
  );

  // Titles — screen headers, section headers, card titles.
  static const TextStyle titleL = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.25,
  );
  static const TextStyle titleM = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
  );
  static const TextStyle titleS = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  // Body.
  static const TextStyle bodyL = TextStyle(fontSize: 15, height: 1.45);
  static const TextStyle bodyM = TextStyle(fontSize: 13.5, height: 1.45);

  // Labels — field labels, buttons, emphasized inline text.
  static const TextStyle labelL = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  static const TextStyle labelM = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  // Captions & overlines.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    height: 1.3,
  );
}
