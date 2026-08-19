import 'package:flutter/material.dart';

/// Spacing scale based on a 4px grid.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double massive = 64;

  static const pageHorizontal = md;
  static const pageVertical = lg;
  static const sectionGap = xl;
  static const itemGap = sm;
  static const cardPadding = lg;
}

/// Border radius tokens — use consistently, never ad-hoc values.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double full = 999;

  static BorderRadius get xsAll => BorderRadius.circular(xs);
  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}

/// Elevation / shadow system — restrained, two levels only.
abstract final class AppShadows {
  static List<BoxShadow> none = const [];

  static List<BoxShadow> sm({Color? color, bool isDark = false}) => [
        BoxShadow(
          color: (color ?? Colors.black)
              .withValues(alpha: isDark ? 0.25 : 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> md({Color? color, bool isDark = false}) => [
        BoxShadow(
          color: (color ?? Colors.black)
              .withValues(alpha: isDark ? 0.35 : 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: (color ?? Colors.black)
              .withValues(alpha: isDark ? 0.15 : 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> lg({Color? color}) => [
        BoxShadow(
          color: (color ?? Colors.black).withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> brand(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.28),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}

/// Icon size tokens.
abstract final class AppIconSize {
  static const double xs = 16;
  static const double sm = 20;
  static const double md = 24;
  static const double lg = 28;
  static const double xl = 32;
}

/// Animation durations for micro-interactions.
abstract final class AppDuration {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
  static const page = Duration(milliseconds: 280);
}

/// Minimum touch target size for accessibility.
abstract final class AppTouchTarget {
  static const double min = 44;
}
