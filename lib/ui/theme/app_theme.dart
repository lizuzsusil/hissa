import 'package:flutter/material.dart';

import '../widgets/motion.dart' show HissaPageTransitionsBuilder;
import 'palette.dart';
import 'tokens.dart';

export 'palette.dart';
export 'tokens.dart';

/// Legacy elevation alias kept for source compatibility; new code should use
/// [AppShadows] instead of Material elevations.
abstract final class AppElevation {
  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 3;
}

/// Builds the light and dark [ThemeData] for the whole product. Every
/// Material component is themed here once so screens never restyle
/// primitives locally.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final p =
        brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.negative,
      surface: p.surface,
      onSurface: p.textPrimary,
    );

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.bg,
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
      displayLarge: AppText.displayL,
      displayMedium: AppText.displayM,
      headlineSmall: AppText.titleM,
      titleLarge: AppText.titleM.copyWith(fontSize: 17),
      titleMedium: AppText.titleS,
      bodyLarge: AppText.bodyL,
      bodyMedium: AppText.bodyM,
      bodySmall: AppText.caption,
      labelLarge: AppText.labelL,
      labelMedium: AppText.labelM,
      labelSmall: AppText.caption,
    ).apply(bodyColor: p.textPrimary, displayColor: p.textPrimary);

    const controlPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: p.textPrimary,
        titleTextStyle: AppText.titleL.copyWith(color: p.textPrimary),
        iconTheme: IconThemeData(color: p.textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? p.surfaceAlt : p.surface,
        hintStyle: TextStyle(color: p.textMuted),
        labelStyle: TextStyle(color: p.textSecondary),
        helperStyle: TextStyle(color: p.textMuted, fontSize: 12),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: AppColors.negative.withValues(alpha: 0.7)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.negative, width: 1.7),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.border.withValues(alpha: 0.6)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xFF272D38) : const Color(0xFF20242C),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: p.borderStrong,
        dragHandleSize: const Size(40, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: AppText.titleM.copyWith(color: p.textPrimary),
        contentTextStyle:
            AppText.bodyM.copyWith(color: p.textSecondary, height: 1.5),
        barrierColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.4),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: isDark ? p.surfaceAlt : AppColors.primary,
        headerForegroundColor: isDark ? p.textPrimary : Colors.white,
        dayStyle: TextStyle(color: p.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.textPrimary.withValues(alpha: 0.08),
          disabledForegroundColor: p.textPrimary.withValues(alpha: 0.35),
          minimumSize: const Size(64, 48),
          textStyle:
              AppText.labelL.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: controlPadding,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: p.textPrimary.withValues(alpha: 0.08),
          disabledForegroundColor: p.textPrimary.withValues(alpha: 0.35),
          minimumSize: const Size(64, 48),
          textStyle:
              AppText.labelL.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: controlPadding,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? p.textPrimary : AppColors.primary,
          disabledForegroundColor: p.textPrimary.withValues(alpha: 0.35),
          minimumSize: const Size(64, 48),
          side: BorderSide(color: p.borderStrong, width: 1.1),
          textStyle:
              AppText.labelL.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: controlPadding,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppText.labelL.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.textSecondary,
          focusColor: AppColors.primary.withValues(alpha: 0.12),
          hoverColor: p.textPrimary.withValues(alpha: 0.05),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.surfaceAlt,
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: p.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
        secondaryLabelStyle: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: Colors.transparent),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : p.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            letterSpacing: 0,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : p.textMuted,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: p.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: p.textMuted,
        indicatorColor: AppColors.primary,
        dividerColor: p.border,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: AppText.labelL.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: AppText.labelL.copyWith(fontWeight: FontWeight.w500),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return p.textMuted;
          return states.contains(WidgetState.selected)
              ? Colors.white
              : (isDark ? p.textMuted : Colors.white);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return p.border.withValues(alpha: 0.6);
          }
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : p.surfaceAlt;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: p.borderStrong, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : p.borderStrong,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF272D38) : const Color(0xFF20242C),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        preferBelow: false,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.border),
        ),
        textStyle: TextStyle(color: p.textPrimary, fontSize: 14),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: p.textPrimary, fontSize: 14.5),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: isDark ? p.surfaceAlt : p.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: p.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: p.border),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: p.surfaceAlt,
        circularTrackColor: p.surfaceAlt.withValues(alpha: 0.4),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: isDark ? 0.36 : 0.22),
        selectionHandleColor: AppColors.primary,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(p.borderStrong),
        radius: const Radius.circular(8),
      ),
    );
  }
}
