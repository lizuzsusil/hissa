import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standardized modal bottom sheet used across the product.
///
/// Applies the shared chrome from [BottomSheetThemeData] (surface, top
/// radius, drag handle) plus a consistent title row, keyboard inset padding
/// and safe areas. On wide screens the sheet is width-capped and centered so
/// tablet/desktop layouts don't stretch controls edge to edge.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool isScrollControlled = false,
  bool showClose = true,
  double? maxHeightFactor = 0.9,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final maxContentHeight =
          maxHeightFactor == null ? null : media.size.height * maxHeightFactor;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxContentHeight ?? double.infinity),
        child: Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: _SheetFrame(
            title: title,
            showClose: showClose && Navigator.of(sheetContext).canPop(),
            child: Builder(builder: builder),
          ),
        ),
      );
    },
  );
}

class _SheetFrame extends StatelessWidget {
  final String? title;
  final bool showClose;
  final Widget child;

  const _SheetFrame({
    required this.child,
    this.title,
    this.showClose = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    // Cap the sheet width on tablets / desktop so forms stay readable.
    final contentWidth = media.size.width > 640 ? 560.0 : double.infinity;

    return Container(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: AppText.titleM.copyWith(color: p.textPrimary),
                      ),
                    ),
                    if (showClose)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
