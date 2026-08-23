import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A rounded surface container used across screens.
///
/// Built on the [AppRadius]/[AppShadows] tokens so every card in the app
/// shares one visual language. [elevation] selects the resting treatment:
/// `0` = flat (hairline border only), `1` = soft ambient lift,
/// `2` = raised (popovers, dragged surfaces).
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;

  /// Overrides [borderRadius] with a full BorderRadius (e.g. asymmetric).
  final BorderRadius? radius;
  final double borderRadius;

  /// Set false when the card sits on an identical-colour background and the
  /// hairline outline is unwanted.
  final bool border;
  final int elevation;
  final VoidCallback? onTap;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.margin = EdgeInsets.zero,
    this.color,
    this.radius,
    this.borderRadius = AppRadius.lg,
    this.border = true,
    this.elevation = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = context.isDark;
    final shape = RoundedRectangleBorder(
      borderRadius: radius ?? BorderRadius.circular(borderRadius),
      side: BorderSide(
        color: border ? p.border : Colors.transparent,
        width: 1,
      ),
    );
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius ?? BorderRadius.circular(borderRadius),
        boxShadow: switch (elevation) {
          <= 0 => const <BoxShadow>[],
          >= 2 => AppShadows.raised(dark: dark),
          _ => AppShadows.card(dark: dark),
        },
      ),
      child: Material(
        color: color ?? p.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Brand-gradient hero surface for dashboard summaries and statements.
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;
  final BorderRadius radius;

  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xxl),
    this.gradient,
    this.radius = const BorderRadius.all(Radius.circular(AppRadius.xl)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.heroGradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Labelled stat row used inside gradient hero surfaces.
class StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: AppGradients.tint(color, alpha: 0.24),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.onHeroMuted
                  : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// A compact metric tile for dashboards and insights: tinted icon well,
/// caption-style label and a prominent value.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppGradients.tint(color),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            label,
            style: AppText.labelM.copyWith(color: p.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppText.titleL.copyWith(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: p.textPrimary,
              ),
            ),
          ),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              caption!,
              style: AppText.caption.copyWith(color: p.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
