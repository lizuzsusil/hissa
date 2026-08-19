import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/models.dart';
import '../theme/app_theme.dart';

/// Renders a category icon in its assigned color.
class CategoryIcon extends StatelessWidget {
  final Category? category;
  final double size;

  const CategoryIcon({super.key, this.category, this.size = 46});

  Color get _color {
    final value = category?.colorValue;
    if (value == null) return AppColors.primary;
    return Color(value);
  }

  IconData get _icon => iconForCodePoint(category?.iconCodePoint);

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.tint(color, alpha: 0.22),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Icon(_icon, size: size * 0.48, color: color),
    );
  }
}

/// Small colour dot used in category pickers.
class ColorDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool selected;

  const ColorDot({
    super.key,
    required this.color,
    this.size = 32,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: selected
            ? Border.all(color: Theme.of(context).colorScheme.surface, width: 3)
            : null,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: selected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
