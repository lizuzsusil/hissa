/// Shared input validators.
///
/// Each function returns an error message when the value is invalid, or
/// `null` when it is acceptable. Error strings are shown inline through
/// [TextField.errorText]. Pass [ValidatorMessages.fromL10n] to render the
/// messages in the active app language.
library;

import 'package:flutter/foundation.dart';

import '../l10n/generated/app_localizations.dart';

/// Localized copy used by the validators. The English defaults are used
/// whenever a specific locale is not supplied.
@immutable
class ValidatorMessages {
  const ValidatorMessages({
    required this.requiredField,
    required this.tooLong,
    required this.emailInvalid,
    required this.passwordTooShort,
    required this.passwordTooLong,
    required this.duplicateMember,
    required this.inviteFormat,
  });

  final String Function(String label) requiredField;
  final String Function(String label, int max) tooLong;
  final String emailInvalid;
  final String passwordTooShort;
  final String passwordTooLong;
  final String duplicateMember;
  final String inviteFormat;

  const ValidatorMessages.en()
      : requiredField = _enRequiredField,
        tooLong = _enTooLong,
        emailInvalid = 'Enter a valid email address',
        passwordTooShort = 'Password must be at least 6 characters',
        passwordTooLong = 'Password must be 64 characters or fewer',
        duplicateMember = 'That name is already in the list',
        inviteFormat = 'Invite codes are 6 characters long';

  factory ValidatorMessages.fromL10n(AppLocalizations l10n) => ValidatorMessages(
        requiredField: l10n.validationFieldRequired,
        tooLong: l10n.validationTooLong,
        emailInvalid: l10n.validationEmailInvalid,
        passwordTooShort: l10n.validationPasswordShort,
        passwordTooLong: l10n.validationPasswordLong,
        duplicateMember: l10n.validationDuplicateMember,
        inviteFormat: l10n.validationInviteFormat,
      );
}

String _enRequiredField(String label) => '$label is required';
String _enTooLong(String label, int max) =>
    '$label must be $max characters or fewer';

/// A required free-text field (trimmed, with an optional length cap).
String? requiredField(
  String? value, {
  String label = 'This field',
  int? maxLength,
  ValidatorMessages messages = const ValidatorMessages.en(),
}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return messages.requiredField(label);
  if (maxLength != null && v.length > maxLength) {
    return messages.tooLong(label, maxLength);
  }
  return null;
}

/// A person/display name: required, trimmed, reasonably short.
String? validateName(
  String? value, {
  String label = 'Name',
  ValidatorMessages messages = const ValidatorMessages.en(),
}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return messages.requiredField(label);
  if (v.length > 40) return messages.tooLong(label, 40);
  return null;
}

final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// A well-formed email address (matches what Firebase Auth will accept).
String? validateEmail(
  String? value, {
  ValidatorMessages messages = const ValidatorMessages.en(),
}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return messages.requiredField('Email address');
  if (!_emailRe.hasMatch(v)) return messages.emailInvalid;
  return null;
}

/// A password of at least 6 characters (Firebase's minimum).
String? validatePassword(
  String? value, {
  ValidatorMessages messages = const ValidatorMessages.en(),
}) {
  final v = value ?? '';
  if (v.isEmpty) return messages.requiredField('Password');
  if (v.length < 6) return messages.passwordTooShort;
  if (v.length > 64) return messages.passwordTooLong;
  return null;
}

final RegExp _inviteRe = RegExp(r'^[A-Z0-9]{6}$');

/// A space invite code: exactly 6 uppercase letters/digits.
String? validateInviteCode(
  String? value, {
  ValidatorMessages messages = const ValidatorMessages.en(),
}) {
  final v = (value ?? '').trim().toUpperCase();
  if (v.isEmpty) {
    return messages.requiredField('Invite code');
  }
  if (!_inviteRe.hasMatch(v)) return messages.inviteFormat;
  return null;
}

/// A member name: required, short, and (optionally) not a duplicate.
String? validateMemberName(
  String? value, {
  Set<String>? existing,
  ValidatorMessages messages = const ValidatorMessages.en(),
}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return messages.requiredField('Member name');
  if (v.length > 40) return messages.tooLong('Name', 40);
  if (existing != null) {
    final normalized = v.toLowerCase();
    final isDuplicate =
        existing.any((e) => e.trim().toLowerCase() == normalized);
    if (isDuplicate) return messages.duplicateMember;
  }
  return null;
}