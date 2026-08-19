import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

/// Resting card shadow used for raised surfaces. Scales with [AppElevation];
/// level 0 yields no shadow at all.
List<BoxShadow> cardShadow({Color? color, double opacity = 0.10}) => [
  BoxShadow(
    color: (color ?? Colors.black).withValues(alpha: opacity),
    blurRadius: 18,
    offset: const Offset(0, 8),
  ),
  BoxShadow(
    color: (color ?? Colors.black).withValues(alpha: opacity * 0.5),
    blurRadius: 6,
    offset: const Offset(0, 2),
  ),
];

/// Wraps a child with press feedback: a subtle scale-down plus darkened tint
/// while the user holds, easing back on release. Use for tappable cards,
/// list rows and buttons to make the app feel alive.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  /// How far the child shrinks while pressed.
  final double scale;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.scale = 0.97,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _down() => setState(() => _pressed = true);
  void _up() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => _down() : null,
      onTapUp: enabled ? (_) => _up() : null,
      onTapCancel: enabled ? _up : null,
      onTap: enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Animates a monetary value between changes with an eased count-up/down.
/// Keeps the previous value as the starting point when the displayed value
/// changes (e.g. from live balance updates).
class AnimatedMoney extends StatelessWidget {
  final int paisa;
  final String Function(int paisa) formatter;
  final TextStyle? style;

  const AnimatedMoney({
    super.key,
    required this.paisa,
    required this.formatter,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: paisa.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) =>
          Text(formatter(value.round()), style: style),
    );
  }
}

/// Animates an integer count (e.g. number of settlements) with a quick ease.
class AnimatedCount extends StatelessWidget {
  final int count;
  final String Function(int count) builder;
  final TextStyle? style;

  const AnimatedCount({
    super.key,
    required this.count,
    required this.builder,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: count.toDouble()),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, _) =>
          Text(builder(value.round()), style: style),
    );
  }
}

/// Fade + slight vertical slide page transition, applied globally for a
/// smoother, more modern navigation feel than a hard cut.
class HissaPageTransitionsBuilder extends PageTransitionsBuilder {
  const HissaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Reveals its child with a staggered fade + slide when it first appears
/// (used for list items so rows animate in instead of popping abruptly).
class Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 320),
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    if (widget.delay > Duration.zero) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _controller.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
