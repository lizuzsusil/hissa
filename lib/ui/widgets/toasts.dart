import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Visual tone for a [showToast] notification.
enum ToastType { info, success, danger, warning }

/// Shows a floating toast on the shared neutral-ink surface with a
/// colour-coded status icon so meaning survives dark mode and colour
/// blindness. Any existing snack bar is dismissed first so consecutive
/// toasts never queue up.
void showToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final style = _ToastStyle.forType(type);
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).snackBarTheme.backgroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        content: Row(
          children: [
            Icon(style.icon, color: style.accent, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        action: onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel ?? context.l10n.ok,
                textColor: style.accent,
                onPressed: onAction,
              ),
      ),
    );
}

class _ToastStyle {
  final Color accent;
  final IconData icon;

  const _ToastStyle(this.accent, this.icon);

  static _ToastStyle forType(ToastType type) {
    switch (type) {
      case ToastType.success:
        return _ToastStyle(
          const Color(0xFF4CC98A),
          Icons.check_circle_rounded,
        );
      case ToastType.danger:
        return _ToastStyle(const Color(0xFFFF8A8D), Icons.error_rounded);
      case ToastType.warning:
        return _ToastStyle(
          const Color(0xFFF5B84F),
          Icons.warning_amber_rounded,
        );
      case ToastType.info:
        return _ToastStyle(const Color(0xFF6FBDEA), Icons.info_rounded);
    }
  }
}
