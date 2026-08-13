import '../models/models.dart';

/// Whether the authenticated user may edit or delete [expense].
///
/// Ownership is enforced server-side by the Firestore security rules (an
/// `Expense` may only be updated/deleted when `createdBy` matches the signed-in
/// user). This helper mirrors that rule so the UI can hide the edit/delete
/// actions for non-creators; the backend remains authoritative.
bool canEditExpenseBy({
  required String? currentUserId,
  required Expense expense,
}) {
  if (currentUserId == null) return false;
  // Legacy expenses without a creator are locked for everyone until migrated.
  if (expense.createdBy == null) return false;
  return expense.createdBy == currentUserId;
}