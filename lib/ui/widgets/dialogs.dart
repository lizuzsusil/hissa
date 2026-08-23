import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Confirmation dialog for important and destructive actions.
///
/// Shows a title, explanatory body, cancel and confirm actions. When
/// [destructive] is true the confirm button renders in the danger colour.
/// If [onConfirm] is provided it runs while the button shows a spinner; the
/// dialog closes only on success (return false or throw to stay open).
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  bool destructive = false,
  IconData? icon,
  Future<bool> Function()? onConfirm,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel ?? context.l10n.confirm,
      destructive: destructive,
      icon: icon,
      onConfirm: onConfirm,
    ),
  ).then((value) => value ?? false);
}

class _ConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final IconData? icon;
  final Future<bool> Function()? onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
    this.icon,
    this.onConfirm,
  });

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (widget.onConfirm == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await widget.onConfirm!();
      if (!mounted) return;
      Navigator.of(context).pop(ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = widget.destructive ? AppColors.negative : AppColors.primary;

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        0,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.icon != null) ...[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppGradients.tint(accent, alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(widget.icon, size: 23, color: accent),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            widget.title,
            style: AppText.titleM.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.message,
            style: AppText.bodyM.copyWith(color: p.textSecondary, height: 1.5),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _busy ? null : () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                style: widget.destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: AppColors.negative,
                        foregroundColor: Colors.white,
                      )
                    : null,
                onPressed: _busy ? null : _confirm,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
