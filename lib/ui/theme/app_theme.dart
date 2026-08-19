import 'package:flutter/material.dart';

import '../widgets/motion.dart' show HissaPageTransitionsBuilder;

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
  static const double xl = kSpacingUnit * 6; // 24
  static const double xxl = kSpacingUnit * 8; // 32
  static const double xxxl = kSpacingUnit * 12; // 48
}

/// Design tokens for corner radii. Controls (buttons, inputs, chips) use
/// [md]; cards use [lg]; elevated/sheet surfaces use [xl].
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 1000;
}

/// Design tokens for elevation. Level 0 is a flat surface (border only);
/// level 1 is a soft resting shadow for cards; level 2 is for raised
/// elements such as the FAB and dialogs.
class AppElevation {
  AppElevation._();

  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 2;
}

/// Design tokens for motion. Durations are kept short and functional so
/// micro-interactions feel responsive rather than sluggish.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

/// Central design tokens for Hissa. Built on the original University of
/// Texas palette (UT blue, burnt orange, gold, forest green) but refreshed
/// into a brighter, more vibrant set of hues so the app reads modern and
/// premium instead of a single flat blue. Neutrals keep the warm, paper-like
/// feel while the brand, semantic and accent colours carry the dynamics.
class AppColors {
  AppColors._();

  // Brand — vivid ocean blue with a brighter highlight for gradients
  static const primary = Color(0xFF1373A8);
  static const primaryDark = Color(0xFF0E5E8D);
  static const primaryDeep = Color(0xFF0A4A70);
  static const primaryBright = Color(0xFF45A8D8);
  static const secondary = Color(0xFFF26B1D); // Burnt Orange (brighter)
  static const secondaryDark = Color(0xFFD4530A);
  static const secondarySoft = Color(0xFFFDECDF);
  static const accent = Color(0xFFF5A623); // Gold
  static const tertiary = Color(0xFF7C5CDB); // Violet accent
  static const tertiarySoft = Color(0xFFF0EBFC);
  static const info = Color(0xFF3D9BE9);
  static const infoSoft = Color(0xFFE7F2FC);
  static const gradientTop = Color(0xFF3EA6DA);
  static const gradientBottom = Color(0xFF0B5B90);

  // Semantic — vibrant but still contrast-safe with white/dark foregrounds
  static const positive = Color(0xFF158A4F); // Forest Green (vivid)
  static const positiveSoft = Color(0xFFE1F4E8);
  static const negative = Color(0xFFD93A40);
  static const negativeSoft = Color(0xFFFDE7E8);
  static const warning = Color(0xFFF5A623); // Gold
  static const warningSoft = Color(0xFFFDF3DE);

  // Surfaces (light) — warm cream, paper-like
  static const bg = Color(0xFFF7F5F1);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF0ECE3); // Cream tint
  static const border = Color(0xFFE5E0D4);
  static const textPrimary = Color(0xFF2B333B); // Iron Grey
  static const textSecondary = Color(0xFF5B6470);
  static const textMuted = Color(0xFF8A939E);

  // Surfaces (dark) — deep blue-black for a richer night mode
  static const bgDark = Color(0xFF0E1116);
  static const surfaceDark = Color(0xFF171B22);
  static const surfaceAltDark = Color(0xFF21262F);
  static const borderDark = Color(0xFF323A48);
  static const textPrimaryDark = Color(0xFFF2F4F7);
  static const textSecondaryDark = Color(0xFFACB5C1);
  static const textMutedDark = Color(0xFF6E7785);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientTop, Color(0xFF1780B8), gradientBottom],
  );

  static const shimmerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5FB6E2), Color(0xFF1E86BE), Color(0xFF0B5E93)],
  );
}

/// Reusable gradients that give the UI its colour dynamics. Hero surfaces stay
/// on the brand blues while action, summary and chart surfaces borrow the warm
/// and accent gradients so no screen feels like a single flat hue.
class AppGradients {
  AppGradients._();

  /// Warm amber-orange, used for money/settle actions.
  static const accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFED6B1E), Color(0xFFDF570A), Color(0xFFB5490A)],
  );

  /// Emerald green for settled/positive moments.
  static const success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34C07E), Color(0xFF12925A)],
  );

  /// Sky blue for info surfaces.
  static const info = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF63C4F5), Color(0xFF1E88D4)],
  );

  /// Violet for premium summary cards.
  static const violet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B7EF0), Color(0xFF6C4FCB)],
  );

  /// Amber for highlights.
  static const warning = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8CC4A), Color(0xFFF2A900)],
  );

  /// Cycling palette for bar charts so each bar/month reads as distinct.
  static const barChart = <LinearGradient>[
    AppColors.heroGradient,
    accent,
    success,
    violet,
    info,
    warning,
  ];

  /// Builds a soft diagonal sheen from a solid [color] for icon wells.
  static LinearGradient tint(Color color, {double alpha = 0.16}) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0.06),
        ],
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          error: AppColors.negative,
        ).copyWith(
          surface: isDark ? AppColors.surfaceDark : AppColors.surface,
          onSurface: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        );

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.bgDark : AppColors.bg,
      fontFamily: 'Roboto',
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: HissaPageTransitionsBuilder(),
          TargetPlatform.iOS: HissaPageTransitionsBuilder(),
          TargetPlatform.macOS: HissaPageTransitionsBuilder(),
          TargetPlatform.windows: HissaPageTransitionsBuilder(),
          TargetPlatform.linux: HissaPageTransitionsBuilder(),
        },
      ),
    );

    final textTheme = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.35),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    final appBarTheme = AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: isDark
          ? AppColors.textPrimaryDark
          : AppColors.textPrimary,
      titleTextStyle: TextStyle(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: appBarTheme,
      cardTheme: CardThemeData(
        elevation: AppElevation.level0,
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.borderDark : AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceAltDark : Colors.white,
        hintStyle: TextStyle(
          color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
        ),
        labelStyle: TextStyle(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
        prefixIconColor: isDark ? AppColors.textMutedDark : AppColors.textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.negative),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.negative, width: 1.8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.surfaceAltDark
            : const Color(0xFF22313F),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: isDark
            ? AppColors.textMutedDark
            : AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : isDark
                ? AppColors.textMutedDark
                : AppColors.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : isDark
                ? AppColors.textMutedDark
                : AppColors.textMuted,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: isDark
            ? AppColors.surfaceAltDark
            : AppColors.surfaceAlt,
        selectedColor: AppColors.primary.withValues(alpha: 0.16),
        labelStyle: TextStyle(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        side: BorderSide.none,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: AppElevation.level2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colorScheme.onSurface.withValues(
            alpha: 0.08,
          ),
          disabledForegroundColor: colorScheme.onSurface.withValues(
            alpha: 0.38,
          ),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 14,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: AppElevation.level1,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : isDark
              ? AppColors.textMutedDark
              : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : isDark
              ? AppColors.surfaceAltDark
              : AppColors.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith((_) => null),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.primary : null,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.primary : null,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: isDark
            ? AppColors.textMutedDark
            : AppColors.textMuted,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceAltDark : const Color(0xFF2B333B),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.primary,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        textStyle: TextStyle(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          fontSize: 14,
        ),
      ),
    );
  }
}
