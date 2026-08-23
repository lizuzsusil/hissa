import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Wraps [child] with a horizontal swipe-to-reveal action (e.g. a Space card
/// revealing a Delete/Leave button). Swiping left slides the child away,
/// revealing [action] pinned to the right edge; swiping right (or tapping the
/// child while open) closes the reveal again.
///
/// Both [child] and [action] are builders that receive a `dismiss` callback so
/// the consumer can close the reveal after interacting with it.
class SwipeRevealAction extends StatefulWidget {
  final Widget Function(void Function() dismiss) child;
  final Widget Function(void Function() dismiss) action;

  /// The width of the revealed [action] strip.
  final double actionWidth;

  /// Reports whether the reveal is open (1.0) or closed (0.0). Useful for
  /// deciding whether tapping the child should dismiss the reveal or perform
  /// its normal action.
  final ValueChanged<bool>? onOpenChanged;

  const SwipeRevealAction({
    super.key,
    required this.child,
    required this.action,
    this.actionWidth = 52,
    this.onOpenChanged,
  });

  @override
  State<SwipeRevealAction> createState() => _SwipeRevealActionState();
}

class _SwipeRevealActionState extends State<SwipeRevealAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  bool get isOpen => _ctrl.value > 0.05;

  void dismiss() => _ctrl.animateTo(0);

  void _report() => widget.onOpenChanged?.call(isOpen);

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _report();
      }
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _ctrl.value = (_ctrl.value - details.delta.dx / widget.actionWidth).clamp(
      0.0,
      1.0,
    );
    _report();
  }

  void _onDragEnd(DragEndDetails details) {
    final wasOpen = isOpen;
    if (_ctrl.value > 0.4) {
      _ctrl.animateTo(
        1,
        curve: Curves.easeOutBack,
        duration: const Duration(milliseconds: 280),
      );
      if (!wasOpen) HapticFeedback.lightImpact();
    } else {
      _ctrl.animateTo(
        0,
        curve: Curves.easeOutCubic,
        duration: const Duration(milliseconds: 220),
      );
    }
    _report();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: widget.actionWidth,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, child) => Transform.scale(
                      scale: 0.85 + 0.15 * _ctrl.value,
                      child: Opacity(
                        opacity: _ctrl.value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                    child: widget.action(dismiss),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => Transform.translate(
                offset: Offset(-widget.actionWidth * _ctrl.value, 0),
                child: widget.child(dismiss),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
