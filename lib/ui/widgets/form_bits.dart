import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Field label rendered above a form control.
class FormLabel extends StatelessWidget {
  final String text;

  const FormLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppText.labelM.copyWith(color: p.textSecondary),
      ),
    );
  }
}

/// Tappable date trigger row. The consumer keeps ownership of its own
/// [showDatePicker] call inside [onTap]; this widget only renders the
/// current [value], formatted via [format].
class DatePickerField extends StatelessWidget {
  final DateTime value;
  final VoidCallback? onTap;
  final String Function(DateTime) format;

  const DatePickerField({
    super.key,
    required this.value,
    required this.onTap,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 20, color: p.textMuted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                format(value),
                style: AppText.titleS.copyWith(color: p.textPrimary),
              ),
            ),
            Icon(Icons.expand_more, size: 22, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Inline validation error banner.
class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final ink = dark ? const Color(0xFFFF9B9E) : AppColors.negative;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.negative.withValues(alpha: 0.14)
            : AppColors.negativeSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: ink),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: AppText.labelM.copyWith(color: ink)),
          ),
        ],
      ),
    );
  }
}

/// Small "You" identity badge shown beside the signed-in user's name.
class ParticipantPill extends StatelessWidget {
  final String label;

  const ParticipantPill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppText.labelM.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
