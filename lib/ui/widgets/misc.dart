import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Section title with optional trailing link-style action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.titleM.copyWith(color: p.textPrimary),
            ),
          ),
          if (actionLabel != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel!,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Semantic pill badge with a status dot. Used for states like pending,
/// approved, rejected and cycle status so colour is never the only signal.
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;

  const StatusBadge({super.key, required this.label, this.tone = BadgeTone.neutral});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final Color fg;
    final Color bg;
    switch (tone) {
      case BadgeTone.positive:
        fg = dark ? const Color(0xFF6FDCA0) : AppColors.positive;
        bg = dark ? AppColors.positive.withValues(alpha: 0.16) : AppColors.positiveSoft;
      case BadgeTone.negative:
        fg = dark ? const Color(0xFFFF9B9E) : AppColors.negative;
        bg = dark ? AppColors.negative.withValues(alpha: 0.16) : AppColors.negativeSoft;
      case BadgeTone.warning:
        fg = dark ? const Color(0xFFF7C56B) : const Color(0xFFA96B04);
        bg = dark ? AppColors.warning.withValues(alpha: 0.16) : AppColors.warningSoft;
      case BadgeTone.info:
        fg = dark ? const Color(0xFF8CC8F2) : const Color(0xFF1D6FA8);
        bg = dark ? AppColors.info.withValues(alpha: 0.16) : AppColors.infoSoft;
      case BadgeTone.brand:
        fg = dark ? AppColors.primaryBright : AppColors.primary;
        bg = AppColors.primary.withValues(alpha: dark ? 0.16 : 0.10);
      case BadgeTone.neutral:
        fg = context.palette.textSecondary;
        bg = context.palette.surfaceAlt;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Semantic tones for [StatusBadge].
enum BadgeTone { positive, negative, warning, info, brand, neutral }

/// Small translucent pill used on gradient hero surfaces to label a space's
/// mode (split / personal).
class ModeChip extends StatelessWidget {
  final String label;

  const ModeChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Tinted inline notice with a leading icon and optional trailing action.
/// Used for income prompts, caps, warnings and tips across screens.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final InfoTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.tone = InfoTone.info,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final Color accent;
    switch (tone) {
      case InfoTone.positive:
        accent = AppColors.positive;
      case InfoTone.warning:
        accent = AppColors.warning;
      case InfoTone.danger:
        accent = AppColors.negative;
      case InfoTone.accent:
        accent = AppColors.secondary;
      case InfoTone.info:
        accent = AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.tint(accent, alpha: dark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: dark ? 0.35 : 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppText.labelL.copyWith(
                fontSize: 13.5,
                color: dark ? AppColors.onHeroMuted : pInk(context, accent),
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.only(left: AppSpacing.sm),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }

  static Color pInk(BuildContext context, Color accent) {
    // Darken light-mode accents slightly for AA text contrast on tints.
    final isDark = context.isDark;
    if (isDark) return accent;
    return Color.lerp(accent, Colors.black, 0.25)!;
  }
}

/// Tone options for [InfoBanner].
enum InfoTone { info, positive, warning, danger, accent }

/// Empty / no-results placeholder: squircle icon well, title, supporting
/// message and an optional primary action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: AppGradients.tint(AppColors.primary, alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDeep.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, size: 34, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.titleM.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.bodyM.copyWith(color: p.textSecondary),
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton loading placeholders
// ---------------------------------------------------------------------------

/// Pulsing placeholder block. Compose [SkeletonLine]/[SkeletonCircle] inside
/// your layout to mirror real content while it loads.
class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonLine({super.key, this.width = double.infinity, this.height = 12});

  @override
  Widget build(BuildContext context) => _SkeletonShape(
        width: width,
        height: height,
        radius: BorderRadius.circular(AppRadius.sm),
      );
}

/// Circular skeleton (avatars, icons).
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) => _SkeletonShape(
        width: size,
        height: size,
        radius: BorderRadius.circular(AppRadius.pill),
      );
}

class _SkeletonShape extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius radius;

  const _SkeletonShape({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  State<_SkeletonShape> createState() => _SkeletonShapeState();
}

class _SkeletonShapeState extends State<_SkeletonShape>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: p.skeletonBase,
          borderRadius: widget.radius,
        ),
      ),
    );
  }
}

/// Standard list-row skeleton matching avatar + two-line rows.
class SkeletonListTile extends StatelessWidget {
  final int count;

  const SkeletonListTile({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const SkeletonCircle(size: 42),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLine(width: double.infinity, height: 13),
                    const SizedBox(height: AppSpacing.sm),
                    SkeletonLine(width: 120, height: 11),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              SkeletonLine(width: 64, height: 14),
            ],
          ),
        ],
      ],
    );
  }
}
