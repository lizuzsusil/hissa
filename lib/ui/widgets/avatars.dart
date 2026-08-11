import 'package:flutter/material.dart';

import '../../core/formatters.dart';

const List<Color> _avatarColors = [
  Color(0xFF6366F1),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFF0EA5E9),
  Color(0xFFEF4444),
  Color(0xFF10B981),
];

Color avatarColorFor(String seed) {
  var hash = 0;
  for (final code in seed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return _avatarColors[hash % _avatarColors.length];
}

/// Circular initials avatar with a stable per-person colour.
class MemberAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool outline;

  const MemberAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = avatarColorFor(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.72)],
        ),
        shape: BoxShape.circle,
        border: outline
            ? Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2.5,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A stack of member avatars with an overflow count.
class AvatarStack extends StatelessWidget {
  final List<String> names;
  final double size;
  final int max;

  const AvatarStack({
    super.key,
    required this.names,
    this.size = 34,
    this.max = 4,
  });

  @override
  Widget build(BuildContext context) {
    final visible = names.take(max).toList();
    final overflow = names.length - visible.length;
    return SizedBox(
      height: size + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * (size * 0.62),
              child: MemberAvatar(name: visible[i], size: size, outline: true),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * (size * 0.62),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A3140)
                      : const Color(0xFFE8EBF4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB6BFD0)
                        : const Color(0xFF5A6273),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
