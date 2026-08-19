import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-width solid primary button with a subtle shadow, press and focus
/// feedback. Focusable so keyboard/tab navigation shows a clear ring.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final button = Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        height: 48,
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryBright, AppColors.primary],
                ),
          color: disabled
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
              : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: _focused && !disabled
              ? Border.all(color: Colors.white, width: 2)
              : null,
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primaryDeep.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: widget.onPressed,
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 19, color: Colors.white),
                          const SizedBox(width: 9),
                        ],
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: disabled
                                ? Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.38)
                                : Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
    if (!widget.expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Outlined secondary button.
class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Optional custom leading widget (e.g. a brand logo). Takes precedence
  /// over [icon] when both are provided.
  final Widget? leading;

  final bool loading;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.leading,
    this.loading = false,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = widget.onPressed == null || widget.loading;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: Material(
          color: isDark ? AppColors.surfaceAltDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color: _focused
                  ? AppColors.primary
                  : isDark
                  ? AppColors.borderDark
                  : AppColors.border,
              width: _focused ? 2 : 1.2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: disabled ? null : widget.onPressed,
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.leading != null) ...[
                          widget.leading!,
                          const SizedBox(width: 9),
                        ] else if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            size: 19,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                          ),
                          const SizedBox(width: 9),
                        ],
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular icon action button.
class IconAction extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;
  final double size;

  /// Accessible label announced by screen readers. Falls back to a text
  /// description of [icon] when not provided.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: widget.tooltip ?? '',
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: InkResponse(
          onTap: widget.onPressed,
          radius: 26,
          child: Semantics(
            button: true,
            label: widget.tooltip,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color:
                    widget.background ??
                    (isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt),
                shape: BoxShape.circle,
                border: _focused
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: Icon(
                widget.icon,
                size: widget.size * 0.5,
                color:
                    widget.foreground ??
                    (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
