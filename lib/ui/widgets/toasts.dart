import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Visual tone for a [showToast] notification.
enum ToastType { info, success, danger, warning }

/// Shows a floating, color-coded toast. Any existing snack bar is dismissed
/// first so consecutive toasts never queue up.
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
        backgroundColor: style.background,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        content: Row(
          children: [
            Icon(style.icon, color: style.foreground, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: style.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        action: onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel ?? context.l10n.ok,
                textColor: style.foreground,
                onPressed: onAction,
              ),
      ),
    );
}

class _ToastStyle {
  final Color background;
  final Color foreground;
  final IconData icon;

  const _ToastStyle(this.background, this.foreground, this.icon);

  static _ToastStyle forType(ToastType type) {
    switch (type) {
      case ToastType.success:
        return _ToastStyle(
          AppColors.positive,
          Colors.white,
          Icons.check_circle_rounded,
        );
      case ToastType.danger:
        return _ToastStyle(
          AppColors.negative,
          Colors.white,
          Icons.error_rounded,
        );
      case ToastType.warning:
        return _ToastStyle(
          AppColors.warning,
          const Color(0xFF3B2E05),
          Icons.warning_amber_rounded,
        );
      case ToastType.info:
        return _ToastStyle(AppColors.primary, Colors.white, Icons.info_rounded);
    }
  }
}
