import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared behaviour for every app button: consistent height, corner radius,
/// typography, loading spinner, disabled treatment and a visible keyboard
/// focus ring. Visual variants differ only in decoration.
class _AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final bool loading;
  final bool expanded;
  final double height;
  final BoxDecoration Function(AppPalette p, bool focused) decoration;
  final Color textColor;

  const _AppButton({
    required this.label,
    required this.decoration,
    required this.textColor,
    this.onPressed,
    this.icon,
    this.leading,
    this.loading = false,
  this.expanded = true,
  this.height = 48,
});

  @override
  State<_AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<_AppButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final disabled = widget.onPressed == null || widget.loading;

    final child = Center(
      widthFactor: widget.expanded ? 1 : null,
      child: widget.loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: widget.textColor,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: AppSpacing.sm),
                ] else if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 19,
                    color: disabled
                        ? widget.textColor.withValues(alpha: 0.5)
                        : widget.textColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
    );

    final button = Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.ease,
        height: widget.height,
        decoration: widget.decoration(p, _focused && !disabled),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: disabled ? null : widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: child,
            ),
          ),
        ),
      ),
    );

    if (!widget.expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Solid brand-blue call-to-action. The single most prominent button on any
/// screen — at most one per view.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return _AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      expanded: expanded,
      height: height,
      textColor: Colors.white,
      decoration: (_, focused) => BoxDecoration(
        color: onPressed == null
            ? context.palette.textPrimary.withValues(alpha: 0.08)
            : AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          if (onPressed != null)
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
        ],
        border: Border.all(
          color: focused ? Colors.white.withValues(alpha: 0.9) : Colors.transparent,
          width: 2,
        ),
      ),
    );
  }
}

/// Tonal secondary action: quiet surface fill, strong ink label.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Custom leading widget (e.g. a brand logo); takes precedence over [icon].
  final Widget? leading;
  final bool loading;
  final bool expanded;
  final double height;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.leading,
    this.loading = false,
    this.expanded = true,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      leading: leading,
      loading: loading,
      expanded: expanded,
      height: height,
      textColor: p.textPrimary,
      decoration: (_, focused) => BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: focused ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
    );
  }
}

/// Hairline outline button for tertiary actions next to filled ones.
class OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? foreground;
  final bool loading;
  final bool expanded;
  final double height;

  const OutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.foreground,
    this.loading = false,
    this.expanded = true,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg =
        foreground ?? (context.isDark ? p.textPrimary : AppColors.primary);
    return _AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      expanded: expanded,
      height: height,
      textColor: fg,
      decoration: (_, focused) => BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: focused ? AppColors.primary : p.borderStrong,
          width: focused ? 2 : 1.2,
        ),
      ),
    );
  }
}

/// Destructive action (delete, remove, reject). Always paired with a
/// confirmation dialog by convention.
class DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final double height;

  const DangerButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return _AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      expanded: expanded,
      height: height,
      textColor: Colors.white,
      decoration: (_, focused) => BoxDecoration(
        color: onPressed == null
            ? context.palette.textPrimary.withValues(alpha: 0.08)
            : AppColors.negative,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          if (onPressed != null)
            BoxShadow(
              color: AppColors.negative.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(
          color: focused ? Colors.white.withValues(alpha: 0.9) : Colors.transparent,
          width: 2,
        ),
      ),
    );
  }
}

/// Low-emphasis inline action rendered as tinted text.
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? foreground;
  final bool expanded;

  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.foreground,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? AppColors.primary;
    final btn = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: fg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Compact circular icon-only control (44px touch target). Used in list rows
/// and app bars; provide [tooltip] for accessibility.
class IconAction extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  /// Fill colour of the circular well; defaults to a subtle surface tint.
  final Color? background;
  final Color? foreground;
  final double size;

  /// Accessible label announced by screen readers and shown as a tooltip.
  final String? tooltip;

  const IconAction({
    super.key,
    required this.icon,
    this.onPressed,
    this.background,
    this.foreground,
    this.size = 40,
    this.tooltip,
  });

  @override
  State<IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<IconAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: widget.tooltip ?? '',
      child: Semantics(
        button: true,
        enabled: widget.onPressed != null,
        label: widget.tooltip,
        child: Focus(
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onPressed,
              child: AnimatedContainer(
                duration: AppMotion.fast,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.background ?? p.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _focused ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: widget.size * 0.48,
                  color:
                      widget.foreground ?? p.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
