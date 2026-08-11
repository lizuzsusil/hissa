import 'dart:math';

final Random _rng = Random();

/// Generates short, URL-friendly, collision-resistant identifiers.
String genId([int length = 10]) {
  const chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(chars[_rng.nextInt(chars.length)]);
  }
  return buffer.toString();
}

/// Generates a short human-friendly invite code (uppercase, readable).
String genInviteCode([int length = 6]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(chars[_rng.nextInt(chars.length)]);
  }
  return buffer.toString();
}
