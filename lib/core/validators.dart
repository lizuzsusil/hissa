/// Shared input validators.
///
/// Each function returns an error message when the value is invalid, or
/// `null` when it is acceptable. Error strings are shown inline through
/// [TextField.errorText].
library;

String? _maxLength(String value, String label, int maxLength) {
  if (value.length > maxLength) {
    return '$label must be $maxLength characters or fewer';
  }
  return null;
}

/// A required free-text field (trimmed, with an optional length cap).
String? requiredField(
  String? value, {
  String label = 'This field',
  int? maxLength,
}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return '$label is required';
  if (maxLength != null) return _maxLength(v, label, maxLength);
  return null;
}

/// A person/display name: required, trimmed, reasonably short.
String? validateName(String? value, {String label = 'Name'}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return '$label is required';
  return _maxLength(v, label, 40);
}

final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// A well-formed email address (matches what Firebase Auth will accept).
String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Email address is required';
  if (!_emailRe.hasMatch(v)) return 'Enter a valid email address';
  return null;
}

/// A password of at least 6 characters (Firebase's minimum).
String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Password is required';
  if (v.length < 6) return 'Password must be at least 6 characters';
  if (v.length > 64) return 'Password must be 64 characters or fewer';
  return null;
}

final RegExp _inviteRe = RegExp(r'^[A-Z0-9]{6}$');

/// A household invite code: exactly 6 uppercase letters/digits.
String? validateInviteCode(String? value) {
  final v = (value ?? '').trim().toUpperCase();
  if (v.isEmpty) return 'Enter the invite code';
  if (!_inviteRe.hasMatch(v)) return 'Invite codes are 6 characters long';
  return null;
}

/// A member name: required, short, and (optionally) not a duplicate.
String? validateMemberName(String? value, {Set<String>? existing}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter a member name';
  final lenErr = _maxLength(v, 'Name', 40);
  if (lenErr != null) return lenErr;
  if (existing != null) {
    final normalized = v.toLowerCase();
    final isDuplicate =
        existing.any((e) => e.trim().toLowerCase() == normalized);
    if (isDuplicate) return 'That name is already in the list';
  }
  return null;
}
