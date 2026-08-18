import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/ids.dart';
import '../core/money.dart';
import '../data/firestore_repository.dart';
import '../data/in_memory_repository.dart';
import '../data/repository.dart';
import '../logic/balances.dart';
import '../logic/expense_auth.dart';
import '../logic/migration.dart';
import '../logic/settlements.dart';
import '../logic/splits.dart';
import '../models/models.dart';
import '../services/fcm_service.dart';

/// Ensures [GoogleSignIn.instance] is initialized exactly once.
bool _googleInitialized = false;

/// Result of trying to join a Space with an invite code. Joining is never
/// immediate: a request is submitted and the Space owner must approve it.
enum SpaceJoinOutcome {
  /// No Space matched the invite code.
  spaceNotFound,

  /// The user already belongs to the Space; it can be opened directly.
  alreadyMember,

  /// A join request for this Space is already pending the owner's decision.
  requestPending,

  /// A new join request was submitted and awaits the owner's approval.
  requestCreated,
}

/// Central application state. Owns the repository and exposes a small,
/// imperative API that the UI calls.
///
/// Authentication is handled by Firebase Auth; account state is persisted
/// natively by the SDK and mirrored to a session blob for the space /
/// cycle selections. When signed in, the repository is a [FirestoreRepository]
/// that keeps local caches in sync via realtime listeners.
class AppState extends ChangeNotifier {
  static const _sessionKey = 'hissa_session_v1';
  static const _introKey = 'hissa_intro_seen_v1';

  ExpenseRepository _repo = InMemoryRepository();
  String? _currentUserId;
  String? _spaceId;
  String? _cycleId;
  String? _onboardingMode;
  bool _introSeen = false;
  bool _loaded = false;
  List<Space> _spaces = [];
  bool _switchingSpace = false;
  List<SpaceJoinRequest> _myPendingSpaceJoinRequests = const [];

  ExpenseRepository get repo => _repo;
  bool get isLoaded => _loaded;
  String? get onboardingMode => _onboardingMode;
  String? get currentUserId => _currentUserId;
  bool get isLoggedIn => _currentUserId != null;
  bool get hasSpace => _spaceId != null;
  bool get introSeen => _introSeen;

  /// True while a Space switch is loading its data, so the shell can show a
  /// loading screen instead of the previous Space's content.
  bool get isSwitchingSpace => _switchingSpace;

  /// The Spaces the current user belongs to (all of them, not just the one
  /// currently selected), used by the post-login Spaces dashboard.
  List<Space> get spaces => List.unmodifiable(_spaces);

  /// Test seam: sets the signed-in user and selected Space without going
  /// through Firebase Auth so widget tests can exercise the UI directly.
  @visibleForTesting
  void debugSetSession({String? userId, String? spaceId}) {
    _currentUserId = userId;
    _spaceId = spaceId;
    _cycleId = null;
  }

  /// Marks the feature-intro carousel as seen so it only shows on first run.
  Future<void> markIntroSeen() async {
    _introSeen = true;
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_introKey, true);
  }

  // ---- session ----

  Future<void> load() async {
    final prefs = SharedPreferencesAsync();
    _introSeen = await prefs.getBool(_introKey) ?? false;
    final sessionRaw = await prefs.getString(_sessionKey);

    String? userId;
    String? spaceId;
    String? cycleId;
    if (sessionRaw != null) {
      try {
        final json = jsonDecode(sessionRaw) as Map<String, dynamic>;
        userId = json['userId'] as String?;
        spaceId = json['spaceId'] as String?;
        cycleId = json['cycleId'] as String?;
        _onboardingMode = json['mode'] as String?;
      } catch (_) {
        // Ignore a corrupt session; the user simply starts signed out.
      }
    }

    // Firebase Auth persists the signed-in user across launches, so a cold
    // start can restore a session without a password.
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      final restore = userId != null && userId == authUser.uid;
      _currentUserId = authUser.uid;
      _spaceId = restore ? spaceId : null;
      _cycleId = restore ? cycleId : null;
      await _attachRepository();
      unawaited(registerPushToken());
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(
      _sessionKey,
      jsonEncode({
        'userId': _currentUserId,
        'spaceId': _spaceId,
        'cycleId': _cycleId,
        'mode': _onboardingMode,
      }),
    );
  }

  Future<void> _commit() async {
    notifyListeners();
    await _persist();
  }

  @override
  void dispose() {
    if (_repo is FirestoreRepository) {
      (_repo as FirestoreRepository).stop();
    }
    super.dispose();
  }

  /// Replaces the repository with a fresh Firestore-backed one subscribed to
  /// the current user's profile and Space.
  ///
  /// Loads every Space the user belongs to into [_spaces] (for the Spaces
  /// dashboard) and keeps the current [_spaceId] selection when the user
  /// is still a member, otherwise falling back to the first available Space.
  ///
  /// When switching Spaces, [targetSpaceId] selects the Space to load and
  /// [knownSpaces] lets the caller skip the extra `findSpacesForUser`
  /// round-trip. The fresh repo is fully loaded *before* it replaces the old
  /// one, so the shell keeps showing the previous Space until the new one is
  /// ready instead of flashing a blank loading screen.
  Future<void> _attachRepository({
    String? targetSpaceId,
    List<Space>? knownSpaces,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return;

    final repo = FirestoreRepository(FirebaseFirestore.instance);
    List<Space> spaces = knownSpaces ?? const [];
    if (knownSpaces == null) {
      try {
        spaces = await repo.findSpacesForUser(uid);
      } catch (_) {
        spaces = const [];
      }
    }
    _spaces = spaces;

    String? nextSpaceId = targetSpaceId;
    if (spaces.isEmpty) {
      nextSpaceId = null;
    } else {
      final stillMember =
          nextSpaceId != null && spaces.any((s) => s.id == nextSpaceId);
      if (!stillMember) {
        nextSpaceId = _spaceId != null && spaces.any((s) => s.id == _spaceId)
            ? _spaceId
            : spaces.first.id;
      }
    }
    if (nextSpaceId != _spaceId) _cycleId = null;

    // Load the full scope into the fresh repo first, then swap atomically.
    await repo.start(
      uid: uid,
      spaceId: nextSpaceId,
      onChanged: notifyListeners,
    );
    if (_repo is FirestoreRepository) {
      (_repo as FirestoreRepository).stop();
    }
    _repo = repo;
    _spaceId = nextSpaceId;
    await _runLegacyMigration(spaces);
    await _rolloverMonthlyCycles();
    notifyListeners();
  }

  /// Phase 7: one-time legacy data migration. Idempotent — it only rewrites
  /// Spaces that still lack an explicit mode and never touches legacy
  /// expenses (ambiguous ones stay read-only historical records).
  ///
  /// [spaces] is the already-fetched Space list so migration does not issue a
  /// redundant `findSpacesForUser` query while switching Spaces.
  Future<void> _runLegacyMigration(List<Space> spaces) async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      final report = await SpaceMigrator().run(
        _repo,
        userId: uid,
        spaces: spaces,
      );
      if (report.spacesAssignedMode > 0) {
        // Refresh the dashboard list so migrated Spaces show their mode.
        _spaces = await _repo.findSpacesForUser(uid);
        notifyListeners();
      }
    } on Exception {
      // Migration is best-effort; existing reads already default to split.
    }
  }

  // ---- auth ----

  Future<void> setOnboardingMode(String mode) async {
    _onboardingMode = mode;
    await _persist();
  }

  Future<bool> signIn({required String email, required String password}) async {
    final normalized = email.trim().toLowerCase();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalized,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') rethrow;
      return false;
    }
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _spaceId = null;
    _cycleId = null;
    await _attachRepository();
    unawaited(registerPushToken());
    await _commit();
    return true;
  }

  Future<bool> signInWithGoogle() async {
    final String uid;
    final String email;
    final String name;
    final String? photoUrl;

    if (kIsWeb) {
      // On web, Firebase Auth performs the Google flow natively (popup) from
      // the web app's config, so no OAuth client id needs to be wired into
      // google_sign_in.
      final UserCredential cred;
      try {
        cred = await FirebaseAuth.instance.signInWithPopup(
          GoogleAuthProvider(),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          throw const GoogleAccountConflictException();
        }
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request' ||
            e.code == 'user-cancelled') {
          return false;
        }
        rethrow;
      }
      final account = cred.user!;
      uid = account.uid;
      email = account.email ?? '';
      name = account.displayName?.trim().isNotEmpty == true
          ? account.displayName!.trim()
          : _capitalize(email.isEmpty ? 'member' : email.split('@').first);
      photoUrl = account.photoURL;
    } else {
      final google = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await google.initialize();
        _googleInitialized = true;
      }

      final GoogleSignInAccount googleAccount;
      try {
        googleAccount = await google.authenticate();
      } on GoogleSignInException catch (e) {
        switch (e.code) {
          case GoogleSignInExceptionCode.canceled:
          case GoogleSignInExceptionCode.interrupted:
          case GoogleSignInExceptionCode.uiUnavailable:
            return false;
          default:
            rethrow;
        }
      }

      final idToken = googleAccount.authentication.idToken;
      if (idToken == null) return false;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      try {
        await FirebaseAuth.instance.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          throw const GoogleAccountConflictException();
        }
        rethrow;
      }

      final authUser = FirebaseAuth.instance.currentUser!;
      uid = authUser.uid;
      email = authUser.email ?? '';
      name = googleAccount.displayName?.trim().isNotEmpty == true
          ? googleAccount.displayName!.trim()
          : _capitalize(email.isEmpty ? 'member' : email.split('@').first);
      photoUrl = authUser.photoURL;
    }

    _currentUserId = uid;
    _spaceId = null;
    _cycleId = null;
    await _attachRepository();
    unawaited(registerPushToken());
    if (currentUser == null) {
      await _repo.saveUser(
        User(
          id: uid,
          name: name,
          email: email,
          avatarUrl: photoUrl,
          createdAt: DateTime.now(),
        ),
      );
    } else if (photoUrl != null && photoUrl != currentUser!.avatarUrl) {
      await _repo.saveUser(currentUser!.copyWith(avatarUrl: photoUrl));
      final member = members.where((m) => m.userId == uid).firstOrNull;
      if (member != null && _spaceId != null) {
        await _repo.saveMember(member.copyWith(avatarUrl: photoUrl), _spaceId);
      }
    }
    await _commit();
    return true;
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: normalized,
      password: password,
    );
    final uid = cred.user!.uid;
    _currentUserId = uid;
    _spaceId = null;
    _cycleId = null;
    await _attachRepository();
    unawaited(registerPushToken());
    final displayName = name.trim().isEmpty
        ? _capitalize(normalized.split('@').first)
        : name.trim();
    await _repo.saveUser(
      User(
        id: uid,
        name: displayName,
        email: normalized,
        createdAt: DateTime.now(),
      ),
    );
    await _commit();
  }

  Future<void> signOut() async {
    if (_repo is FirestoreRepository) {
      (_repo as FirestoreRepository).stop();
    }
    _repo = InMemoryRepository();
    _currentUserId = null;
    _spaceId = null;
    _cycleId = null;
    _spaces = [];
    _myPendingSpaceJoinRequests = const [];
    try {
      await FirebaseAuth.instance.signOut();
    } on Exception {
      // Local session is cleared regardless.
    }
    await _commit();
  }

  /// Registers the current device's FCM token for the signed-in user so the
  /// backend can push group request lifecycle notifications to them. Best
  /// effort: failures never block the auth flow.
  Future<void> registerPushToken() async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      await FcmMessagingService.register(userId: uid);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> updateProfile(String name) async {
    final user = currentUser;
    if (user == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _repo.saveUser(user.copyWith(name: trimmed));
    final member = members.where((m) => m.userId == user.id).firstOrNull;
    if (member != null && _spaceId != null) {
      await _repo.saveMember(member.copyWith(name: trimmed), _spaceId);
    }
    await _commit();
  }

  // ---- current selections ----

  User? get currentUser {
    if (_currentUserId == null) return null;
    return _repo.users.where((u) => u.id == _currentUserId).firstOrNull;
  }

  Space? get space {
    if (_spaceId == null) return null;
    return _repo.spaces.where((s) => s.id == _spaceId).firstOrNull;
  }

  List<SpaceMember> get members {
    if (_spaceId == null) return const [];
    return _repo.members.toList();
  }

  bool get isOwner {
    final user = currentUser;
    if (user == null) return false;
    return members.any(
      (m) => m.userId == user.id && m.role == MemberRole.owner,
    );
  }

  List<Cycle> get cycles {
    if (_spaceId == null) return const [];
    final all = _repo.cycles.where((c) => c.spaceId == _spaceId).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return all;
  }

  Cycle? get activeCycle {
    if (_spaceId == null) return null;
    final active = _repo.cycles
        .where((c) => c.spaceId == _spaceId && c.status == CycleStatus.active)
        .firstOrNull;
    if (active != null) return active;
    return _repo.cycles.where((c) => c.spaceId == _spaceId).toList().lastOrNull;
  }

  Cycle? get selectedCycle {
    if (_cycleId == null) return activeCycle;
    return _repo.cycles.where((c) => c.id == _cycleId).firstOrNull ??
        activeCycle;
  }

  Future<void> selectCycle(String cycleId) async {
    _cycleId = cycleId;
    await _persist();
    notifyListeners();
  }

  /// Switches to a different Space the user belongs to, re-attaching the
  /// repository so the shell reflects the newly selected Space.
  Future<void> selectSpace(String spaceId) async {
    if (!_spaces.any((s) => s.id == spaceId)) return;
    if (_spaceId == spaceId) {
      notifyListeners();
      return;
    }
    _cycleId = null;
    // Signal the shell to show a loading screen while the new Space's data is
    // fetched, then swap the repository once it is fully loaded.
    _switchingSpace = true;
    notifyListeners();
    try {
      await _attachRepository(targetSpaceId: spaceId, knownSpaces: _spaces);
    } finally {
      _switchingSpace = false;
    }
    await _commit();
  }

  /// Member count for the given Space, used by the Spaces dashboard.
  Future<int> countMembers(String spaceId) async {
    try {
      return await _repo.countMembers(spaceId);
    } catch (_) {
      return 1;
    }
  }

  List<Category> get categories {
    if (_spaceId == null) return const [];
    return _repo.categories.where((c) => c.spaceId == _spaceId).toList();
  }

  // ---- space ----

  Future<bool> createSpace({
    required String name,
    required String currency,
    required List<String> memberEmails,
    required SpaceMode mode,
    CycleType cycleType = CycleType.monthly,
  }) async {
    final user = currentUser;
    if (user == null) return false;

    final spaceId = 'h_${genId(8)}';
    final space = Space(
      id: spaceId,
      name: name.trim().isEmpty ? 'Our Home' : name.trim(),
      currency: currency,
      inviteCode: genInviteCode(),
      createdAt: DateTime.now(),
      createdBy: user.id,
      updatedAt: DateTime.now(),
      mode: mode,
      cycleType: cycleType,
    );
    // The owner membership is written before the Space so security rules
    // (which gate Space writes on membership) accept the create.
    await _repo.saveMember(
      SpaceMember(
        userId: user.id,
        name: user.name,
        role: MemberRole.owner,
        joinedAt: DateTime.now(),
        avatarUrl: user.avatarUrl,
      ),
      spaceId,
    );
    await _repo.saveSpace(space);

    for (final email in memberEmails) {
      final trimmed = email.trim().toLowerCase();
      if (trimmed.isEmpty) continue;
      final known = _repo.users.any((u) => u.email.toLowerCase() == trimmed);
      if (known) continue;
      final newUser = User(
        id: 'u_${genId(8)}',
        name: _nameFromEmail(trimmed),
        email: trimmed,
        createdAt: DateTime.now(),
      );
      await _repo.saveUser(newUser);
      await _repo.saveMember(
        SpaceMember(
          userId: newUser.id,
          name: newUser.name,
          role: MemberRole.member,
          joinedAt: DateTime.now(),
          invitedEmail: trimmed,
          invitedByUserId: user.id,
        ),
        spaceId,
      );
    }

    await _seedCategories(spaceId);
    if (mode != SpaceMode.personal) {
      await _startCycleFor(spaceId, DateTime.now(), cycleType: cycleType);
    }

    _spaceId = spaceId;
    _cycleId = null;
    await _attachRepository();
    await _commit();
    return true;
  }

  /// Attempts to join the Space matching [code]. Joining is never immediate:
  /// the Space owner must approve the request (mirroring the member group
  /// flow). Returns an [SpaceJoinOutcome] describing what happened.
  Future<SpaceJoinOutcome> requestSpaceJoin(String code) async {
    final user = currentUser;
    if (user == null) return SpaceJoinOutcome.spaceNotFound;
    final normalized = code.trim().toUpperCase();
    final space = await _repo.findSpaceByInviteCode(normalized);
    if (space == null) return SpaceJoinOutcome.spaceNotFound;

    // Already a member: open the Space directly. Skip the re-attach when the
    // repository is already attached to this Space.
    if (_repo.members.any((m) => m.userId == user.id)) {
      if (_spaceId != space.id) {
        _spaceId = space.id;
        _cycleId = null;
        await _attachRepository();
      }
      await _commit();
      return SpaceJoinOutcome.alreadyMember;
    }

    // A request is already pending for this Space: keep the pending state.
    final existing = await _repo.findPendingSpaceJoinRequest(space.id, user.id);
    if (existing != null) return SpaceJoinOutcome.requestPending;

    await _repo.saveSpaceJoinRequest(
      SpaceJoinRequest(
        id: 'j_${genId(8)}',
        spaceId: space.id,
        requesterUserId: user.id,
        requesterName: user.name,
        createdAt: DateTime.now(),
      ),
    );
    return SpaceJoinOutcome.requestCreated;
  }

  /// Resolves a Space by its invite code. Used by the join screen to display
  /// the pending state (space name) after a request is submitted. Returns null
  /// when no Space matches.
  Future<Space?> findSpaceByCode(String code) =>
      _repo.findSpaceByInviteCode(code.trim().toUpperCase());

  /// Invites [email] to the current Space: creates (or reuses) a profile for
  /// the address, adds them as a member and triggers the backend invite email.
  ///
  /// Returns false when the email already belongs to a member of the Space.
  Future<bool> inviteMember(String email) async {
    final s = space;
    final user = currentUser;
    if (s == null || user == null) return false;
    final trimmed = email.trim().toLowerCase();
    if (trimmed.isEmpty) return false;
    if (_repo.members.any(
      (m) => m.userId == user.id && user.email.toLowerCase() == trimmed,
    )) {
      return false;
    }
    if (_repo.members.any(
      (m) =>
          m.userId != user.id &&
          (_repo.users
                  .where((u) => u.id == m.userId)
                  .firstOrNull
                  ?.email
                  .toLowerCase() ==
              trimmed),
    )) {
      return false;
    }

    var newUser = _repo.users
        .where((u) => u.email.toLowerCase() == trimmed)
        .firstOrNull;
    newUser ??= User(
      id: 'u_${genId(8)}',
      name: _nameFromEmail(trimmed),
      email: trimmed,
      createdAt: DateTime.now(),
    );
    await _repo.saveUser(newUser);
    await _repo.saveMember(
      SpaceMember(
        userId: newUser.id,
        name: newUser.name,
        role: MemberRole.member,
        joinedAt: DateTime.now(),
        avatarUrl: newUser.avatarUrl,
        invitedEmail: trimmed,
        invitedByUserId: user.id,
      ),
      s.id,
    );
    await _commit();
    return true;
  }

  /// Approves a pending Space join request: the requester becomes a member of
  /// the Space (the backend notifies them by email and push). Owner only.
  Future<void> approveSpaceJoinRequest(String requestId) async {
    final request = _repo.spaceJoinRequests
        .where((r) => r.id == requestId)
        .firstOrNull;
    if (request == null || request.status != SpaceJoinRequestStatus.pending) {
      return;
    }
    if (!isOwner) return;
    final requester = _repo.users
        .where((u) => u.id == request.requesterUserId)
        .firstOrNull;
    await _repo.saveMember(
      SpaceMember(
        userId: request.requesterUserId,
        name: requester?.name ?? request.requesterName,
        role: MemberRole.member,
        joinedAt: DateTime.now(),
        avatarUrl: requester?.avatarUrl,
      ),
      request.spaceId,
    );
    await _repo.updateSpaceJoinRequestStatus(
      requestId,
      SpaceJoinRequestStatus.approved,
    );
    await _commit();
  }

  /// Rejects a pending Space join request. The requester is notified by email
  /// and push. Owner only.
  Future<void> rejectSpaceJoinRequest(String requestId) async {
    final request = _repo.spaceJoinRequests
        .where((r) => r.id == requestId)
        .firstOrNull;
    if (request == null || request.status != SpaceJoinRequestStatus.pending) {
      return;
    }
    if (!isOwner) return;
    await _repo.updateSpaceJoinRequestStatus(
      requestId,
      SpaceJoinRequestStatus.rejected,
    );
    await _commit();
  }

  Future<void> renameSpace(String name) async {
    final s = space;
    if (s == null) return;
    await _repo.saveSpace(
      s.copyWith(name: name.trim().isEmpty ? s.name : name.trim()),
    );
    await _commit();
  }

  Future<void> renameSpaceCurrency(String code) async {
    final s = space;
    if (s == null) return;
    await _repo.saveSpace(s.copyWith(currency: code));
    await _commit();
  }

  /// Derives a readable display name from an email address's local part, e.g.
  /// `john.doe@example.com` -> `John Doe`.
  static String _nameFromEmail(String email) {
    final local = email.split('@').first;
    final parts = local
        .split(RegExp(r'[._\-+]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return local;
    return parts.map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
  }

  Future<void> removeMember(String userId) async {
    if (userId == currentUser?.id) return;
    final spaceId = _spaceId;
    if (spaceId == null) return;
    // §52: a group whose owner leaves the Space is deactivated (never
    // auto-transferred); historical expenses still reference it.
    for (final g in _repo.memberGroups) {
      if (g.spaceId != spaceId) continue;
      if (g.ownerUserId == userId && g.isActive) {
        await _repo.saveMemberGroup(g.copyWith(isActive: false));
      }
      // §53: a leaving member is removed from any groups they belong to.
      if (g.memberIds.contains(userId)) {
        await _repo.removeGroupMember(g.id, userId);
      }
    }
    await _repo.removeMember(userId, spaceId);
    await _commit();
  }

  // ---- categories ----

  Future<void> addCategory(String name, IconData icon, Color color) async {
    final s = space;
    if (s == null) return;
    await _repo.saveCategory(
      Category(
        id: 'cat_${genId(8)}',
        spaceId: s.id,
        name: name.trim(),
        iconCodePoint: icon.codePoint,
        colorValue: color.toARGB32(),
        isDefault: false,
      ),
    );
    await _commit();
  }

  Future<void> _seedCategories(String spaceId) async {
    for (final preset in kDefaultCategories) {
      await _repo.saveCategory(
        Category.preset(
          id: 'cat_${preset.name.toLowerCase()}',
          spaceId: spaceId,
          name: preset.name,
          icon: preset.icon,
          color: preset.color,
        ),
      );
    }
  }

  // ---- cycles ----

  /// Closed (historical) cycles of the current Space, newest first.
  List<Cycle> get closedCycles {
    if (_spaceId == null) return const [];
    return _repo.cycles
        .where(
          (c) => c.spaceId == _spaceId && c.status == CycleStatus.closed,
        )
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  List<Expense> expensesForCycle(String cycleId) {
    final list = _repo.expenses.where((e) => e.cycleId == cycleId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> _startCycleFor(
    String spaceId,
    DateTime anchor, {
    required CycleType cycleType,
  }) async {
    if (cycleType == CycleType.monthly) {
      final start = DateTime(anchor.year, anchor.month, 1);
      final end = DateTime(anchor.year, anchor.month + 1, 0);
      final existing = _repo.cycles
          .where(
            (c) =>
                c.spaceId == spaceId &&
                c.startDate.year == start.year &&
                c.startDate.month == start.month,
          )
          .firstOrNull;
      if (existing != null) return;
      await _repo.saveCycle(
        Cycle(
          id: 'c_${genId(8)}',
          spaceId: spaceId,
          name: '${_monthLabel(start)} ${start.year}',
          startDate: start,
          endDate: end,
          status: CycleStatus.active,
        ),
      );
      return;
    }

    // Custom cycle: open-ended, named "Cycle N" by default. The end date is
    // the same as the start until the owner closes the cycle.
    final existingActive = _repo.cycles
        .where((c) => c.spaceId == spaceId && c.status == CycleStatus.active)
        .firstOrNull;
    if (existingActive != null) return;
    final count = _repo.cycles.where((c) => c.spaceId == spaceId).length;
    await _repo.saveCycle(
      Cycle(
        id: 'c_${genId(8)}',
        spaceId: spaceId,
        name: 'Cycle ${count + 1}',
        startDate: anchor,
        endDate: anchor,
        status: CycleStatus.active,
      ),
    );
  }

  /// Closes the currently selected cycle. Only the Space owner may close a
  /// cycle, and only when every balance is settled.
  Future<void> closeCycle() async {
    if (!isOwner) return;
    final cycle = selectedCycle;
    if (cycle == null || cycle.status == CycleStatus.closed) return;
    final balances = computeBalances(cycle.id);
    final hasOutstanding = balances.any((b) => !b.remaining.isZero);
    if (hasOutstanding) return;
    await _repo.saveCycle(
      cycle.copyWith(
        status: CycleStatus.closed,
        closedAt: DateTime.now(),
        endDate: DateTime.now(),
      ),
    );
    await _commit();
  }

  /// Starts a new cycle after the current one ends. Only the Space owner may
  /// start a cycle. Monthly Spaces always open the running calendar month;
  /// custom Spaces open a new "Cycle N".
  Future<void> startNewCycle() async {
    if (!isOwner) return;
    final s = space;
    final cycle = selectedCycle;
    if (s == null) return;
    final anchor = DateTime.now();
    if (cycle != null && cycle.status == CycleStatus.active) {
      await _repo.saveCycle(
        cycle.copyWith(
          status: CycleStatus.closed,
          closedAt: DateTime.now(),
          endDate: DateTime.now(),
        ),
      );
    }
    await _startCycleFor(s.id, anchor, cycleType: s.cycleType);
    _cycleId = null;
    await _commit();
  }

  /// Renames [cycleId] (used for custom cycles). Only the Space owner may
  /// rename a cycle. Returns true when the rename was applied.
  Future<bool> renameCycle(String cycleId, String name) async {
    if (!isOwner) return false;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final cycle = _repo.cycles.where((c) => c.id == cycleId).firstOrNull;
    if (cycle == null) return false;
    await _repo.saveCycle(cycle.copyWith(name: trimmed));
    notifyListeners();
    return true;
  }

  /// For [CycleType.monthly] Spaces: when the app opens and the active cycle
  /// belongs to a previous calendar month, close it and open the running
  /// month's cycle. This keeps monthly Spaces in sync with the calendar even
  /// when nobody closes a cycle on the 1st of a new month.
  Future<void> _rolloverMonthlyCycles() async {
    final s = space;
    if (s == null || s.cycleType != CycleType.monthly) return;
    final active = _repo.cycles
        .where((c) => c.spaceId == s.id && c.status == CycleStatus.active)
        .firstOrNull;
    if (active == null) return;
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final activeMonth = DateTime(active.startDate.year, active.startDate.month, 1);
    if (activeMonth.isAtSameMomentAs(currentMonth)) return;
    await _repo.saveCycle(
      active.copyWith(status: CycleStatus.closed, closedAt: now),
    );
    await _startCycleFor(s.id, now, cycleType: CycleType.monthly);
    _cycleId = null;
    notifyListeners();
  }

  @visibleForTesting
  Future<void> debugRunMonthlyRollover() => _rolloverMonthlyCycles();

  // ---- expenses ----

  /// Whether every participant and every participant-group member belongs to
  /// the selected Space. A client must never be able to include a user who is
  /// not a member (security rule mirrored in the Firestore rules).
  bool _participantsAreMembers(
    List<String> participantIds,
    List<ParticipantGroup> groups,
  ) {
    if (_spaceId == null) return false;
    final memberIds = {for (final m in _repo.members) m.userId};
    for (final id in participantIds) {
      if (!memberIds.contains(id)) return false;
    }
    for (final g in groups) {
      for (final id in g.userIds) {
        if (!memberIds.contains(id)) return false;
      }
    }
    return true;
  }

  /// Rebinds each group's [ParticipantGroup.expenseId] to [expenseId]. The
  /// form creates groups before the expense document exists, so the reference
  /// is fixed here at save time.
  List<ParticipantGroup> _bindGroups(
    List<ParticipantGroup> groups,
    String expenseId,
  ) {
    return [
      for (final g in groups)
        ParticipantGroup(
          id: g.id,
          expenseId: expenseId,
          name: g.name,
          userIds: g.userIds,
          percentage: g.percentage,
          shares: g.shares,
          customAmountPaisa: g.customAmountPaisa,
        ),
    ];
  }

  /// Validates that all referenced MemberGroups belong to the current Space
  /// and are active.
  bool _memberGroupsAreValid(List<MemberGroup> memberGroups) {
    if (memberGroups.isEmpty) return true;
    final spaceId = _spaceId;
    if (spaceId == null) return false;
    for (final g in memberGroups) {
      if (!g.isActive || g.spaceId != spaceId) return false;
    }
    return true;
  }

  /// Builds split parties from individual participants, old ad-hoc groups,
  /// and new persistent MemberGroups.
  List<SplitParty> _partiesFrom({
    required List<String> participantIds,
    required List<ParticipantGroup> groups,
    required List<MemberGroup> memberGroups,
  }) {
    final groupedUserIds = <String>{};
    final groupParties = <SplitParty>[];

    // Old model: ad-hoc ParticipantGroup from expense form
    for (final g in groups) {
      groupedUserIds.addAll(g.userIds);
      groupParties.add(
        SplitParty.group(groupId: g.id, name: g.name, userIds: g.userIds),
      );
    }

    // New model: persistent MemberGroups selected from Settings
    for (final g in memberGroups) {
      // Dedup against every user the group represents (owner + members) so the
      // owner cannot also be selected individually and double-counted.
      groupedUserIds.addAll(g.allUserIds);
      groupParties.add(
        SplitParty.group(groupId: g.id, name: g.name, userIds: g.memberIds),
      );
    }

    return [
      for (final id in participantIds)
        if (!groupedUserIds.contains(id)) SplitParty.individual(id),
      ...groupParties,
    ];
  }

  /// Attaches group snapshots to ExpenseShare for persistent MemberGroups.
  /// NOTE: intentionally a no-op for now — group snapshots (historical
  /// membership auditability) are not yet persisted. The shares still carry
  /// `memberGroupId` so historical amounts remain fixed.
  void _attachGroupSnapshots(
    List<ExpenseShare> shares,
    List<MemberGroup> memberGroups,
  ) {}

  Future<void> addExpense({
    required String description,
    required Money amount,
    required DateTime date,
    String? categoryId,
    String? note,
    required List<String> participantIds,
    List<ParticipantGroup> groups = const [],
    List<MemberGroup> memberGroups = const [],
    SplitType splitType = SplitType.equal,
    Map<String, double> percentages = const {},
    Map<String, Money> customAmounts = const {},
    Map<String, int> shareUnits = const {},
  }) async {
    final s = space;
    final cycle = selectedCycle;
    if (s == null || cycle == null) return;
    // Validate both old ad-hoc groups and new persistent groups
    if (!_participantsAreMembers(participantIds, groups)) return;
    if (!_memberGroupsAreValid(memberGroups)) return;
    final expenseId = 'e_${genId(8)}';
    final expense = Expense(
      id: expenseId,
      spaceId: s.id,
      cycleId: cycle.id,
      // Phase 5: an expense is always paid for by the authenticated user.
      paidByUserId: payerForCurrentUser(_currentUserId),
      createdBy: _currentUserId,
      amount: amount,
      categoryId: categoryId,
      description: description.trim().isEmpty ? 'Expense' : description.trim(),
      date: date,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      participantGroups: _bindGroups(groups, expenseId),
    );
    // Build parties from individual participants + old ad-hoc groups + new persistent member groups
    final parties = _partiesFrom(
      participantIds: participantIds,
      groups: groups,
      memberGroups: memberGroups,
    );
    final shares = SplitCalculator.buildGrouped(
      expenseId: expense.id,
      amount: expense.amount,
      parties: parties,
      type: splitType,
      percentages: percentages,
      customAmounts: customAmounts,
      shareUnits: shareUnits,
    );
    // Attach group snapshots for persistent MemberGroups
    _attachGroupSnapshots(shares, memberGroups);
    await _repo.saveExpense(expense, shares);
    await _commit();
  }

  Future<void> updateExpense(
    Expense expense, {
    required String description,
    required Money amount,
    required DateTime date,
    String? categoryId,
    String? note,
    required List<String> participantIds,
    List<ParticipantGroup> groups = const [],
    List<MemberGroup> memberGroups = const [],
    SplitType splitType = SplitType.equal,
    Map<String, double> percentages = const {},
    Map<String, Money> customAmounts = const {},
    Map<String, int> shareUnits = const {},
  }) async {
    if (!canEditExpense(expense)) return;
    if (!_participantsAreMembers(participantIds, groups)) return;
    if (!_memberGroupsAreValid(memberGroups)) return;
    final updated = expense.copyWith(
      description: description.trim().isEmpty ? 'Expense' : description.trim(),
      amount: amount,
      date: date,
      categoryId: categoryId,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      participantGroups: _bindGroups(groups, expense.id),
    );
    final parties = _partiesFrom(
      participantIds: participantIds,
      groups: groups,
      memberGroups: memberGroups,
    );
    final shares = SplitCalculator.buildGrouped(
      expenseId: expense.id,
      amount: updated.amount,
      parties: parties,
      type: splitType,
      percentages: percentages,
      customAmounts: customAmounts,
      shareUnits: shareUnits,
    );
    _attachGroupSnapshots(shares, memberGroups);
    await _repo.saveExpense(updated, shares);
    await _commit();
  }

  Future<void> deleteExpense(String expenseId) async {
    final expense = _repo.expenses.where((e) => e.id == expenseId).firstOrNull;
    if (expense == null || !canEditExpense(expense)) return;
    await _repo.deleteExpense(expenseId);
    await _commit();
  }

  // ---- personal expenses (personal / personal mode) ----

  /// Whether the selected Space is a Personal (personal) space.
  bool get isPersonalMode {
    final s = space;
    return s != null && s.mode == SpaceMode.personal;
  }

  /// Personal expenses: those created without a cycle (cycleId == null) in
  /// the selected Space, most recent first.
  List<Expense> get personalExpenses {
    if (_spaceId == null) return const [];
    final list =
        _repo.expenses
            .where((e) => e.spaceId == _spaceId && e.cycleId == null)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Sum of personal expenses whose [date] falls within [month].
  Money personalTotalSpent(DateTime month) {
    var paisa = 0;
    for (final e in personalExpenses) {
      if (e.date.year == month.year && e.date.month == month.month) {
        paisa += e.amount.paisa;
      }
    }
    return Money(paisa);
  }

  Future<void> addPersonalExpense({
    required String description,
    required Money amount,
    required DateTime date,
    String? categoryId,
    String? note,
  }) async {
    final s = space;
    if (s == null) return;
    final expense = Expense(
      id: 'e_${genId(8)}',
      spaceId: s.id,
      cycleId: null,
      paidByUserId: _currentUserId ?? '',
      createdBy: _currentUserId,
      amount: amount,
      categoryId: categoryId,
      description: description.trim().isEmpty ? 'Expense' : description.trim(),
      date: date,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _repo.saveExpense(expense, const []);
    await _commit();
  }

  Future<void> updatePersonalExpense(
    Expense expense, {
    required String description,
    required Money amount,
    required DateTime date,
    String? categoryId,
    String? note,
  }) async {
    final updated = expense.copyWith(
      description: description.trim().isEmpty ? 'Expense' : description.trim(),
      amount: amount,
      date: date,
      categoryId: categoryId,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
    );
    await _repo.saveExpense(updated, const []);
    await _commit();
  }

  // ---- settlements ----

  Future<void> addSettlement({
    required String fromUserId,
    required String toUserId,
    required Money amount,
    required String paymentMethod,
    required DateTime date,
    String? note,
  }) async {
    final s = space;
    final cycle = selectedCycle;
    if (s == null || cycle == null) return;
    await _repo.saveSettlement(
      Settlement(
        id: 's_${genId(8)}',
        spaceId: s.id,
        cycleId: cycle.id,
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        currency: s.currency,
        paymentMethod: paymentMethod,
        date: date,
        note: note?.trim().isEmpty ?? true ? null : note!.trim(),
        status: SettlementStatus.paid,
        createdAt: DateTime.now(),
      ),
    );
    await _commit();
  }

  // ---- derived calculations ----

  List<Expense> get expensesInCycle {
    final cycle = selectedCycle;
    if (cycle == null) return const [];
    final list = _repo.expenses.where((e) => e.cycleId == cycle.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<ExpenseShare> sharesForExpense(String expenseId) {
    return _repo.sharesForExpense(expenseId);
  }

  /// Whether the current user may edit or delete [expense].
  ///
  /// Mirrors the Firestore security rules: only the expense creator may
  /// update/delete it. Legacy expenses without a creator are locked.
  bool canEditExpense(Expense expense) =>
      canEditExpenseBy(currentUserId: _currentUserId, expense: expense);

  List<Settlement> get settlementsInCycle {
    final cycle = selectedCycle;
    if (cycle == null) return const [];
    return _repo.settlements.where((s) => s.cycleId == cycle.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<BalanceInfo> computeBalances([String? cycleId]) {
    final s = space;
    final cycle = cycleId == null
        ? selectedCycle
        : _repo.cycles.where((c) => c.id == cycleId).firstOrNull;
    if (s == null || cycle == null) return const [];
    // BalanceCalculator returns entries for users AND Member Groups. A group is
    // a financial participant: its share is never attributed to its members, so
    // the group's own balance must be surfaced for the sheet to reconcile.
    final entries = BalanceCalculator.compute(
      space: s,
      members: members,
      memberGroups: _repo.memberGroups,
      cycle: cycle,
      expenses: _repo.expenses,
      shares: _repo.shares,
      settlements: _repo.settlements,
    );
    return entries
        .map(
          (e) => BalanceInfo(
            userId: e.id,
            paid: e.paid,
            share: e.share,
            balance: e.balance,
            settledOut: e.settledOut,
            settledIn: e.settledIn,
          ),
        )
        .toList();
  }

  Money totalSpent([String? cycleId]) {
    final cycle = cycleId == null
        ? selectedCycle
        : _repo.cycles.where((c) => c.id == cycleId).firstOrNull;
    if (cycle == null) return Money.zero();
    return BalanceCalculator.totalSpent(_repo.expenses, cycle.id);
  }

  List<SettlementProposal> settlementProposals([String? cycleId]) {
    final balances = computeBalances(cycleId);
    final map = <String, Money>{};
    for (final b in balances) {
      map[b.userId] = b.remaining;
    }
    return SettlementCalculator.minimize(map);
  }

  String? memberName(String id) {
    final member = members.where((m) => m.userId == id).firstOrNull;
    if (member != null) return member.name;
    // A balance/settlement entry may reference a Member Group as a financial
    // participant, so resolve group ids to the group name too.
    return _repo.memberGroups.where((g) => g.id == id).firstOrNull?.name;
  }

  /// Active Member Groups in the currently selected Space.
  List<MemberGroup> get activeMemberGroups {
    final sid = _spaceId;
    return _repo.memberGroups
        .where((g) => g.spaceId == sid && g.isActive)
        .toList();
  }

  /// Pending Space join requests in the currently selected Space. Only the
  /// Space owner sees these (and only they may approve/reject).
  List<SpaceJoinRequest> get pendingSpaceJoinRequests {
    final sid = _spaceId;
    if (sid == null) return const [];
    return _repo.spaceJoinRequests
        .where(
          (r) => r.spaceId == sid && r.status == SpaceJoinRequestStatus.pending,
        )
        .toList();
  }

  /// Pending Space join requests the current user has submitted across Spaces,
  /// including Spaces they are not a member of yet. Loaded and kept fresh by
  /// [refreshPendingSpaceJoinRequests] so the join screen can keep the
  /// requester in a persistent pending state until every request is resolved.
  List<SpaceJoinRequest> get myPendingSpaceJoinRequests =>
      _myPendingSpaceJoinRequests;

  /// Re-queries the current user's pending join requests (Firestore) and
  /// resolves each pending Space into [_spaces] so the join screen can show
  /// Space names and navigate into a Space after an approval.
  ///
  /// Returns the Spaces whose join request was resolved (approved) since the
  /// last refresh, so the caller can land the user inside their new Space.
  /// Never throws: on any failure it keeps the previous pending list.
  Future<List<Space>> refreshPendingSpaceJoinRequests() async {
    final uid = _currentUserId;
    if (uid == null) return const [];
    final before = _myPendingSpaceJoinRequests.map((r) => r.spaceId).toSet();
    try {
      final requests = await _repo.fetchMyPendingSpaceJoinRequests(uid);
      _myPendingSpaceJoinRequests = requests;

      final pendingNow = requests.map((r) => r.spaceId).toSet();
      final resolved = [...before.difference(pendingNow)];
      for (final r in requests) {
        final space = await _repo.fetchSpaceById(r.spaceId);
        if (space != null) _upsertSpace(space);
      }
      notifyListeners();

      if (resolved.isEmpty) return const [];
      final userSpaces = await _repo.findSpacesForUser(uid);
      return userSpaces.where((s) => resolved.contains(s.id)).toList();
    } catch (_) {
      notifyListeners();
      return const [];
    }
  }

  /// The display name of a Space by id, resolved from the known Spaces list.
  /// Returns null when the Space is not known.
  String? spaceNameById(String spaceId) =>
      _spaces.where((s) => s.id == spaceId).firstOrNull?.name;

  void _upsertSpace(Space space) {
    final i = _spaces.indexWhere((s) => s.id == space.id);
    if (i >= 0) {
      _spaces[i] = space;
    } else {
      _spaces = [..._spaces, space];
    }
  }

  /// Every user ID (owner + members) represented by any active Member Group in
  /// the current Space. Used to prevent double counting and to exclude grouped
  /// users from being treated as individual split participants (Rule 8).
  Set<String> get groupedUserIds {
    final ids = <String>{};
    for (final g in activeMemberGroups) {
      ids.addAll(g.allUserIds);
    }
    return ids;
  }

  /// Whether Member Group functionality applies to the current Space. Groups
  /// require at least three members; a two-member Space cannot form a
  /// meaningful group, so group creation is disabled (Rule 3 / Rule 11).
  bool get memberGroupsApplicable => members.length >= 3;

  /// The maximum number of users a single Member Group may contain, including
  /// the group owner. A group can hold at most (space members - 1) users so at
  /// least one member always remains ungrouped (e.g. a 4-user space allows
  /// groups of up to 3, a 5-user space up to 4). Groups need at least 2 users
  /// (owner + 1), which is guaranteed whenever the space has >= 3 members.
  int get maxGroupMembers => members.length - 1;

  /// The number of users (excluding the group owner) that may still be added to
  /// a group that currently has [currentMemberCount] member rows.
  int groupMemberSlotsRemaining(int currentMemberCount) =>
      maxGroupMembers - 1 - currentMemberCount;

  /// Pending (unresolved) Member Group creation requests in the current Space.
  List<GroupRequest> get pendingGroupRequests {
    final sid = _spaceId;
    return _repo.groupRequests
        .where(
          (r) => r.spaceId == sid && r.status == GroupRequestStatus.pending,
        )
        .toList();
  }

  /// All Member Group creation requests in the current Space.
  List<GroupRequest> get groupRequests {
    final sid = _spaceId;
    return _repo.groupRequests.where((r) => r.spaceId == sid).toList();
  }

  /// Whether [userId] has a pending group creation request already. Prevents a
  /// non-owner from spamming duplicate requests.
  bool hasPendingGroupRequest(String userId) =>
      pendingGroupRequests.any((r) => r.requesterUserId == userId);

  /// Whether the current user is eligible to submit a group creation request:
  /// they must be a non-owner in a Space with at least three members, must not
  /// already belong to an active group, must not already have a pending
  /// request, and must have at least one other ungrouped member they can group
  /// with.
  bool get canRequestGroup =>
      !isOwner &&
      memberGroupsApplicable &&
      !groupedUserIds.contains(currentUser?.id) &&
      !hasPendingGroupRequest(currentUser?.id ?? '') &&
      requestableGroupMembers.isNotEmpty;

  /// Members the current user could still add to a requested group. Excludes
  /// the current user, the Space owner, and anyone already in an active group.
  List<SpaceMember> get requestableGroupMembers {
    final me = currentUser?.id;
    final grouped = groupedUserIds;
    return members
        .where((m) => m.userId != me)
        .where((m) => m.role != MemberRole.owner)
        .where((m) => !grouped.contains(m.userId))
        .toList();
  }

  /// Submits a pending request to create a Member Group containing the current
  /// user plus [memberUserIds]. Returns the created request, or null if the
  /// current user is not eligible.
  Future<GroupRequest?> requestGroup(List<String> memberUserIds) async {
    final me = currentUser;
    final sid = _spaceId;
    if (me == null || sid == null || !canRequestGroup) return null;
    if (hasPendingGroupRequest(me.id)) return null;
    // Rule: a group can hold at most (space members - 1) users including the
    // requester, so the requested member count must fit within the cap.
    if (memberUserIds.length > maxGroupMembers - 1) return null;
    final request = GroupRequest(
      id: genId(8),
      spaceId: sid,
      requesterUserId: me.id,
      memberUserIds: List.of(memberUserIds),
      status: GroupRequestStatus.pending,
      createdAt: DateTime.now(),
    );
    await _repo.saveGroupRequest(request);
    notifyListeners();
    return request;
  }

  /// Approves [requestId] by creating a Member Group owned by the requester
  /// with the requested members. Only the Space owner may approve. Returns the
  /// created group, or null if the request is invalid or cannot be satisfied.
  Future<MemberGroup?> approveGroupRequest(String requestId) async {
    if (!isOwner) return null;
    final request = _repo.groupRequests
        .where((r) => r.id == requestId)
        .firstOrNull;
    if (request == null || request.status != GroupRequestStatus.pending) {
      return null;
    }
    // Rule 2 (one group per user): reject a stale request if any of its users
    // already belongs to an active group, so approval can never put a user
    // (including the owner) into a second group.
    final alreadyGrouped = groupedUserIds;
    final involved = [request.requesterUserId, ...request.memberUserIds];
    if (involved.any(alreadyGrouped.contains)) return null;
    // Rule: a group can hold at most (space members - 1) users including the
    // requester/owner; reject a request that exceeds the cap.
    if (involved.length > maxGroupMembers) return null;
    final now = DateTime.now();
    final group = MemberGroup(
      id: genId(8),
      spaceId: request.spaceId,
      ownerUserId: request.requesterUserId,
      name: _ownerGroupName(request.requesterUserId),
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.saveMemberGroup(group);
    for (final uid in request.memberUserIds) {
      await _repo.addGroupMember(group.id, uid);
    }
    await _repo.updateGroupRequestStatus(
      requestId,
      GroupRequestStatus.approved,
    );
    notifyListeners();
    return group;
  }

  /// Rejects [requestId]. Only the Space owner may reject.
  Future<void> rejectGroupRequest(String requestId) async {
    if (!isOwner) return;
    await _repo.updateGroupRequestStatus(
      requestId,
      GroupRequestStatus.rejected,
    );
    notifyListeners();
  }

  String _ownerGroupName(String ownerId) {
    final ownerName = memberName(ownerId);
    return ownerName == null || ownerName.isEmpty
        ? "Owner's Group"
        : "$ownerName's Group";
  }

  /// The profile photo for [userId], resolved from the user profile first and
  /// falling back to the member record (which may lag behind the profile).
  String? memberAvatarUrl(String userId) {
    final user = _repo.users.where((u) => u.id == userId).firstOrNull;
    final url = user?.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return url;
    }
    return members.where((m) => m.userId == userId).firstOrNull?.avatarUrl;
  }

  /// The profile photo for a user whose name is [name], or null when the name
  /// does not resolve to a user with a photo. Used as a last-resort fallback
  /// for avatar widgets that only know a display name.
  String? avatarUrlForName(String name) {
    final user = _repo.users
        .where((u) => u.name == name)
        .where((u) => u.avatarUrl != null && u.avatarUrl!.isNotEmpty)
        .firstOrNull;
    return user?.avatarUrl;
  }

  Category? categoryFor(String? categoryId) {
    if (categoryId == null) return null;
    return _repo.categories.where((c) => c.id == categoryId).firstOrNull;
  }
}

String _monthLabel(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[d.month - 1];
}

String _capitalize(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1);
}

/// Thrown by [AppState.signInWithGoogle] when the Google account's email is
/// already used by an email/password account, so the user should sign in with
/// email + password (or link the accounts later) instead.
class GoogleAccountConflictException implements Exception {
  const GoogleAccountConflictException();
}
