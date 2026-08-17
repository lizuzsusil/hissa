import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../state/app_state.dart';

const List<Color> _avatarColors = [
  Color(0xFF3D7DE0), // royal blue
  Color(0xFFF26B1D), // amber orange
  Color(0xFF2FA362), // emerald green
  Color(0xFF7C5CDB), // violet
  Color(0xFFE5484D), // coral red
  Color(0xFF14B8A6), // teal
  Color(0xFFF5A623), // gold
  Color(0xFF6366F1), // indigo
];

Color avatarColorFor(String seed) {
  var hash = 0;
  for (final code in seed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return _avatarColors[hash % _avatarColors.length];
}

/// Circular avatar that shows a photo when [avatarUrl] is provided and falls
/// back to initials otherwise, with a stable per-person colour.
class MemberAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool outline;
  final String? avatarUrl;

  const MemberAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.outline = false,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final color = avatarColorFor(name);
    final url = avatarUrl ?? _resolveFromState(context);
    final Widget child;
    if (url != null && url.isNotEmpty) {
      child = ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initials(color),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _initials(color);
          },
        ),
      );
    } else {
      child = _initials(color);
    }
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
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _initials(Color color) {
    return Text(
      initialsOf(name),
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.36,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  /// Resolves the profile photo for [name] from the current space's user
  /// profiles, so avatars rendered with only a display name still show the
  /// profile image when one exists.
  String? _resolveFromState(BuildContext context) {
    return context.read<AppState>().avatarUrlForName(name);
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
                      ? const Color(0xFF21262F)
                      : const Color(0xFFF0ECE3),
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
                        ? const Color(0xFF6E7785)
                        : const Color(0xFF5B6470),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
