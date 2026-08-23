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
  String? _defaultSpaceId;
  bool _introSeen = false;
  bool _loaded = false;
  AppNotification? pendingNotification;
  List<Space> _spaces = [];
  bool _switchingSpace = false;
  List<SpaceJoinRequest> _myPendingSpaceJoinRequests = const [];
  List<Space> _pendingSpaces = const [];
  static const _notificationsReadKey = 'hissa_notifications_read_v1';
  DateTime? _notificationsReadAt;

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

  /// Spaces the current user owns (i.e. [Space.createdBy] == current user ID).
  List<Space> get ownedSpaces {
    final uid = _currentUserId;
    if (uid == null) return const [];
    return _spaces.where((s) => s.createdBy == uid).toList();
  }

  /// Spaces the current user has joined but does not own. [spaces] already
  /// only contains Spaces the user is a member of, so we simply exclude the
  /// ones they created.
  List<Space> get joinedSpaces {
    final uid = _currentUserId;
    if (uid == null) return const [];
    return _spaces.where((s) => s.createdBy != uid).toList();
  }

  /// The Space the user chose to open automatically on the next launch (when
  /// they belong to more than one Space). Null when no default is set.
  String? get defaultSpaceId => _defaultSpaceId;

  /// Test seam: sets the signed-in user and selected Space without going
  /// through Firebase Auth so widget tests can exercise the UI directly.
  @visibleForTesting
  void debugSetSession({String? userId, String? spaceId}) {
    _currentUserId = userId;
    _spaceId = spaceId;
    _cycleId = null;
  }

  /// Injects a repository so tests can exercise failure paths (e.g. a
  /// notification write denied by Firestore rules) without Firebase.
  @visibleForTesting
  void debugSetRepo(ExpenseRepository repo) {
    _repo = repo;
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
    final notificationsReadRaw = await prefs.getString(_notificationsReadKey);
    if (notificationsReadRaw != null) {
      _notificationsReadAt = DateTime.tryParse(notificationsReadRaw);
    }

    String? userId;
    String? spaceId;
    String? cycleId;
    if (sessionRaw != null) {
      try {
        final json = jsonDecode(sessionRaw) as Map<String, dynamic>;
        userId = json['userId'] as String?;
        spaceId = json['spaceId'] as String?;
        cycleId = json['cycleId'] as String?;
        _defaultSpaceId = json['defaultSpaceId'] as String?;
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
        'defaultSpaceId': _defaultSpaceId,
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
    // The database profile is the source of truth for the default Space, so
    // a fresh login on any device routes directly to the chosen Space.
    syncDefaultSpaceFromProfile();
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
        // `serverClientId` is the Web (type 3) OAuth client from google-services.json / Firebase console.
        // Without it Android returns `idToken == null` → [28404] Failed to retrieve an ID token.
        await google.initialize(
          serverClientId:
              '398063641965-4vmkv5n0a04l6cdofn7ccgbg0g4rcboo.apps.googleusercontent.com',
        );
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
    _defaultSpaceId = null;
    _spaces = [];
    _myPendingSpaceJoinRequests = const [];
    _pendingSpaces = const [];
    try {
      await FirebaseAuth.instance.signOut();
    } on Exception {
      // Local session is cleared regardless.
    }
    await _commit();
  }

  /// The Space that should open automatically on launch: the user's only
  /// Space, or their chosen default Space when they still belong to it.
  /// Null means the Spaces dashboard should be shown for the user to pick.
  Space? get launchSpace {
    if (_spaces.length == 1) return _spaces.first;
    final defaultId = _defaultSpaceId;
    if (defaultId != null) {
      for (final s in _spaces) {
        if (s.id == defaultId) return s;
      }
    }
    return null;
  }

  /// Sets the Space that should open automatically on the next launch. Pass
  /// null (or a Space the user no longer belongs to) to clear the preference.
  ///
  /// The preference is written to the user's database profile so it follows
  /// the account across devices and logins; the session blob is only a local
  /// fast path for the current device.
  Future<void> setDefaultSpace(String? spaceId) async {
    final String? target;
    if (spaceId == null) {
      target = null;
    } else if (_spaces.any((s) => s.id == spaceId)) {
      target = spaceId;
    } else {
      // Not a member of that Space: keep the current preference untouched.
      return;
    }
    if (_defaultSpaceId == target) return;
    _defaultSpaceId = target;
    notifyListeners();
    final user = currentUser;
    if (user != null) {
      await _repo.saveUser(user.copyWith(defaultSpaceId: target));
    }
    await _persist();
  }

  /// Copies the database-stored default Space preference into memory so a
  /// fresh login (on any device) lands the user directly in their chosen
  /// Space. The database is the source of truth; the local session blob is
  /// only a fast path for the current device.
  void syncDefaultSpaceFromProfile() {
    _defaultSpaceId = currentUser?.defaultSpaceId;
  }

  /// Whether [userId] (default: the signed-in user) owns [spaceId]. Ownership
  /// is derived from the Space creator, falling back to the membership role
  /// when the Space's members are loaded.
  bool isOwnerOf(String spaceId, [String? userId]) {
    final uid = userId ?? _currentUserId;
    if (uid == null) return false;
    final s = _spaces.where((s) => s.id == spaceId).firstOrNull;
    if (s != null && s.createdBy == uid) return true;
    final member = _repo.members
        .where((m) => m.spaceId == spaceId && m.userId == uid)
        .firstOrNull;
    return member?.role == MemberRole.owner;
  }

  /// Total outstanding balance for [userId] in [spaceId] across every open
  /// cycle. Non-zero means the member must settle before leaving.
  Future<Money> outstandingDuesFor(String spaceId, String userId) =>
      _repo.fetchOutstandingDues(spaceId, userId);

  /// Permanently deletes [spaceId] and all of its data. Only the owner may
  /// delete a Space; the owner leaves by deleting instead.
  Future<bool> deleteSpace(String spaceId) async {
    final uid = _currentUserId;
    if (uid == null || !isOwnerOf(spaceId)) return false;
    await _repo.deleteSpace(spaceId);
    if (_spaceId == spaceId) {
      _spaceId = null;
      _cycleId = null;
    }
    await refreshSpaces();
    await _commit();
    return true;
  }

  /// Removes the current user from [spaceId] as a member. The owner cannot
  /// leave (they must delete the Space), and a member with any outstanding
  /// balance must settle first. Historical transactions are never modified:
  /// the user only stops being included in new ones.
  Future<bool> leaveSpace(String spaceId) async {
    final uid = _currentUserId;
    if (uid == null || isOwnerOf(spaceId)) return false;
    final outstanding = await _repo.fetchOutstandingDues(spaceId, uid);
    if (!outstanding.isZero) return false;
    await _repo.removeMember(uid, spaceId);
    if (_spaceId == spaceId) {
      _spaceId = null;
      _cycleId = null;
    }
    await refreshSpaces();
    await _commit();
    return true;
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
    // Keep biometric account picker in sync with the display name
    try {
      const accountsKey = 'hissa_biometric_accounts_v1';
      final prefs = SharedPreferencesAsync();
      final raw = await prefs.getString(accountsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        var changed = false;
        for (final m in list) {
          if (m['uid'] == user.id) {
            m['name'] = trimmed;
            changed = true;
          }
        }
        if (changed) await prefs.setString(accountsKey, jsonEncode(list));
      }
    } catch (_) {}
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
    final seen = <String>{};
    return _repo.members.where((m) => seen.add(m.userId)).toList();
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
    // A Space awaiting approval is never enterable: the user is not a member
    // until the owner approves their join request.
    if (isPendingSpace(spaceId)) return;
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

    // Already a member of *this* Space: open the Space directly. Skip the
    // re-attach when the repository is already attached to this Space.
    // Membership is checked against the target Space (its member list), never
    // the currently attached Space's member cache — the requester may belong
    // to another Space and must not be treated as an instant member of the
    // Space they are trying to join.
    final targetMembers = await _repo.fetchSpaceMembers(space.id);
    if (targetMembers.any((m) => m.userId == user.id)) {
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

    final request = SpaceJoinRequest(
      id: 'j_${genId(8)}',
      spaceId: space.id,
      requesterUserId: user.id,
      requesterName: user.name,
      createdAt: DateTime.now(),
    );
    await _repo.saveSpaceJoinRequest(request);
    // Notify the Space owner(s) so the join request shows up in their inbox
    // even though the requester is not yet a member of the Space.
    final owners = await _repo.fetchSpaceMembers(space.id);
    for (final owner in owners.where((m) => m.role == MemberRole.owner)) {
      await _saveNotificationFor(
        recipientId: owner.userId,
        type: NotificationType.spaceJoinRequested,
        eventKey: request.id,
        spaceId: space.id,
        extra: {'spaceId': space.id},
      );
    }
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
    final hadAccount = newUser != null;
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
    // Only a registered invitee can receive a push; an unknown address is
    // reached by email alone (no account / FCM token exists yet).
    if (hadAccount) {
      await _saveNotificationFor(
        recipientId: newUser.id,
        type: NotificationType.spaceInvited,
        eventKey: '${s.id}_${newUser.id}',
        spaceId: s.id,
        extra: {'spaceId': s.id},
      );
    }
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
    await _saveNotificationFor(
      recipientId: request.requesterUserId,
      type: NotificationType.spaceJoinApproved,
      eventKey: request.id,
      spaceId: request.spaceId,
      extra: {'spaceId': request.spaceId},
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
    await _saveNotificationFor(
      recipientId: request.requesterUserId,
      type: NotificationType.spaceJoinRejected,
      eventKey: request.id,
      spaceId: request.spaceId,
      extra: {'spaceId': request.spaceId},
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
        .where((c) => c.spaceId == _spaceId && c.status == CycleStatus.closed)
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
    final activeMonth = DateTime(
      active.startDate.year,
      active.startDate.month,
      1,
    );
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
    await _notifyExpenseChanged(expense, updated: false);
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
    await _notifyExpenseChanged(updated, updated: true);
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

  // ---- personal estimated expenses (Personal mode only) ----

  /// Estimated (planned) expenses for the selected Personal space. Estimates
  /// are kept fully separate from real expenses so they can never leak into
  /// actual spending totals or balances.
  List<EstimatedExpense> get estimatedExpenses {
    if (_spaceId == null) return const [];
    return _repo.estimatedExpenses.where((e) => e.spaceId == _spaceId).toList();
  }

  /// Estimated expenses whose [EstimatedExpense.month] falls within [month].
  List<EstimatedExpense> estimatedExpensesForMonth(DateTime month) {
    return estimatedExpenses
        .where(
          (e) => e.month.year == month.year && e.month.month == month.month,
        )
        .toList();
  }

  /// Total estimated amount for [month].
  Money estimatedTotalForMonth(DateTime month) {
    var paisa = 0;
    for (final e in estimatedExpensesForMonth(month)) {
      paisa += e.amount.paisa;
    }
    return Money(paisa);
  }

  /// Adds a planned amount for [month] (defaults to the current month).
  Future<void> addEstimatedExpense({
    required String description,
    required Money amount,
    String? categoryId,
    DateTime? month,
  }) async {
    final s = space;
    if (s == null || amount.isZero) return;
    final targetMonth = month == null
        ? DateTime(DateTime.now().year, DateTime.now().month)
        : DateTime(month.year, month.month);
    // Only one planned amount per month: if one already exists, edit it
    // instead (updateEstimatedExpense).
    if (estimatedExpensesForMonth(targetMonth).isNotEmpty) {
      return;
    }
    final now = DateTime.now();
    final estimate = EstimatedExpense(
      id: 'est_${genId(8)}',
      spaceId: s.id,
      amount: amount,
      categoryId: categoryId,
      description: description.trim().isEmpty
          ? 'Planned expense'
          : description.trim(),
      month: targetMonth,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.saveEstimatedExpense(estimate);
    await _commit();
  }

  Future<void> updateEstimatedExpense(
    EstimatedExpense estimate, {
    required String description,
    required Money amount,
    String? categoryId,
    DateTime? month,
  }) async {
    final updated = estimate.copyWith(
      description: description.trim().isEmpty
          ? 'Planned expense'
          : description.trim(),
      amount: amount,
      categoryId: categoryId,
      month: month == null ? estimate.month : DateTime(month.year, month.month),
    );
    await _repo.saveEstimatedExpense(updated);
    await _commit();
  }

  Future<void> deleteEstimatedExpense(String estimateId) async {
    await _repo.deleteEstimatedExpense(estimateId);
    await _commit();
  }

  // ---- settlements ----

  /// The balance-sheet entity that carries [userId]'s finances: their active
  /// Member Group when they belong to one, otherwise the user themselves.
  String financialEntityFor(String userId) {
    final group = activeMemberGroups
        .where((g) => g.allUserIds.contains(userId))
        .firstOrNull;
    return group?.id ?? userId;
  }

  /// The signed-in user as a balance-sheet participant ([financialEntityFor]).
  String? get myFinancialEntityId =>
      _currentUserId == null ? null : financialEntityFor(_currentUserId!);

  /// Maximum amount [debtorId] may still request from [creditorId] this
  /// cycle: the pairwise outstanding after approved settlements, minus any
  /// other requests still awaiting a decision between the two.
  Money outstandingBetween(String debtorId, String creditorId) {
    final balances = {for (final b in computeBalances()) b.userId: b.remaining};
    final owedBy = -(balances[debtorId]?.paisa ?? 0);
    final owedTo = balances[creditorId]?.paisa ?? 0;
    final cap = owedBy < owedTo ? owedBy : owedTo;
    final pendingBetween = _repo.settlements
        .where(
          (s) =>
              s.cycleId == selectedCycle?.id &&
              s.status.awaitsDecision &&
              s.fromUserId == debtorId &&
              s.toUserId == creditorId,
        )
        .fold<int>(0, (acc, s) => acc + s.amount.paisa);
    final left = cap - pendingBetween;
    return left > 0 ? Money(left) : Money.zero();
  }

  /// Step 1 of the Split-Mode approval flow: the DEBTOR submits a settlement
  /// request to [toUserId] (the creditor). The request stays unsettled until
  /// the creditor approves it via [approveSettlement]. Only the member who
  /// actually owes money may call this; the amount cannot exceed what is
  /// still outstanding between the two.
  Future<bool> requestSettlement({
    required String toUserId,
    required Money amount,
    required String paymentMethod,
    required DateTime date,
    String? note,
  }) async {
    final s = space;
    final cycle = selectedCycle;
    final me = _currentUserId;
    if (s == null || cycle == null || me == null) return false;

    // Permission: only the debtor initiates. The requesting entity must be
    // the one carrying the debt (the user or their Member Group).
    final myEntity = financialEntityFor(me);
    if (myEntity == financialEntityFor(toUserId)) return false;

    if (amount.paisa <= 0 ||
        amount.paisa > outstandingBetween(myEntity, toUserId).paisa) {
      return false;
    }

    final settlementId = 's_${genId(8)}';
    await _repo.saveSettlement(
      Settlement(
        id: settlementId,
        spaceId: s.id,
        cycleId: cycle.id,
        fromUserId: myEntity,
        toUserId: toUserId,
        amount: amount,
        currency: s.currency,
        paymentMethod: paymentMethod,
        date: date,
        note: note?.trim().isEmpty ?? true ? null : note!.trim(),
        status: SettlementStatus.pendingApproval,
        createdAt: DateTime.now(),
      ),
    );
    await _saveNotificationFor(
      recipientId: toUserId,
      type: NotificationType.settlementRequested,
      eventKey: settlementId,
      spaceId: s.id,
      extra: {
        'settlementId': settlementId,
        'spaceId': s.id,
        'amount': amount.paisa,
      },
    );
    await _commit();
    return true;
  }

  /// Step 2 of the flow: the CREDITOR approves a pending settlement request,
  /// marking it settled. Balances update immediately because only approved
  /// settlements are counted by the balance calculator. Only the member who
  /// is owed the money may approve.
  Future<bool> approveSettlement(String settlementId) async {
    final me = _currentUserId;
    final settlement = _repo.settlements
        .where((x) => x.id == settlementId)
        .firstOrNull;
    if (me == null ||
        settlement == null ||
        !settlement.status.awaitsDecision ||
        !settlement.isCreditor(financialEntityFor(me))) {
      return false;
    }
    await _repo.saveSettlement(
      settlement.copyWith(
        status: SettlementStatus.approved,
        respondedAt: DateTime.now(),
      ),
    );
    await _saveNotificationFor(
      recipientId: settlement.fromUserId,
      type: NotificationType.settlementApproved,
      eventKey: settlementId,
      spaceId: settlement.spaceId,
      extra: {
        'settlementId': settlementId,
        'spaceId': settlement.spaceId,
        'amount': settlement.amount.paisa,
      },
    );
    await _commit();
    return true;
  }

  /// Step 2 (rejected): the CREDITOR declines a pending settlement request.
  /// The record stays unsettled and the debtor may submit a new request.
  /// Only the member who is owed the money may reject.
  Future<bool> rejectSettlement(String settlementId) async {
    final me = _currentUserId;
    final settlement = _repo.settlements
        .where((x) => x.id == settlementId)
        .firstOrNull;
    if (me == null ||
        settlement == null ||
        !settlement.status.awaitsDecision ||
        !settlement.isCreditor(financialEntityFor(me))) {
      return false;
    }
    await _repo.saveSettlement(
      settlement.copyWith(
        status: SettlementStatus.rejected,
        respondedAt: DateTime.now(),
      ),
    );
    await _saveNotificationFor(
      recipientId: settlement.fromUserId,
      type: NotificationType.settlementRejected,
      eventKey: settlementId,
      spaceId: settlement.spaceId,
      extra: {
        'settlementId': settlementId,
        'spaceId': settlement.spaceId,
        'amount': settlement.amount.paisa,
      },
    );
    await _commit();
    return true;
  }

  // ---- hissa income (Split Spaces) ----

  /// Hissa incomes recorded in the current cycle, newest first.
  List<HissaIncome> get hissaIncomesInCycle {
    final cycle = selectedCycle;
    if (cycle == null) return const [];
    return _repo.hissaIncomes.where((i) => i.cycleId == cycle.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Total hissa income for [cycleId] (defaults to the selected cycle).
  Money totalHissaIncome([String? cycleId]) {
    final id = cycleId ?? selectedCycle?.id;
    if (id == null) return Money.zero();
    return BalanceCalculator.totalIncome(_repo.hissaIncomes, id);
  }

  /// Whether every [partyId] is a valid financial participant of the current
  /// Space: either an individual member OR an active Member Group. Income
  /// parties follow the exact same rule as expense parties (Rule 8): grouped
  /// members participate through their group, never individually.
  bool _incomePartiesAreValid(List<String> partyIds) {
    final sid = _spaceId;
    if (sid == null) return false;
    final memberIds = {for (final m in _repo.members) m.userId};
    final groupIds = {
      for (final g in _repo.memberGroups)
        if (g.spaceId == sid && g.isActive) g.id,
    };
    for (final id in partyIds) {
      if (!memberIds.contains(id) && !groupIds.contains(id)) return false;
    }
    // A grouped member must never appear alongside (or instead of) their
    // group: their finances are carried by the group entity.
    final grouped = groupedUserIds;
    final activeGroupIds = groupIds;
    for (final id in partyIds) {
      if (activeGroupIds.contains(id)) continue;
      if (grouped.contains(id)) return false;
    }
    return true;
  }

  /// Records a shared hissa contribution (Split Spaces only). The member
  /// who received the money is only its holder — the benefit is distributed
  /// across [participantIds] with the same split rules used for expenses,
  /// lowering everyone's share of the net hissa expense. Both the receiver
  /// and the participants may be individual members OR Member Groups.
  Future<bool> addHissaIncome({
    required String description,
    required Money amount,
    required DateTime date,
    required String receivedByUserId,
    String? categoryId,
    String? note,
    required List<String> participantIds,
    SplitType splitType = SplitType.equal,
    Map<String, double> percentages = const {},
    Map<String, Money> customAmounts = const {},
    Map<String, int> shareUnits = const {},
  }) async {
    final s = space;
    final cycle = selectedCycle;
    if (s == null || s.mode == SpaceMode.personal || cycle == null) {
      return false;
    }
    // Same participation guarantees as expenses: only real Space members or
    // active Member Groups, and no grouped member split individually.
    if (!_incomePartiesAreValid(participantIds)) return false;
    if (!_incomePartiesAreValid([receivedByUserId])) return false;
    if (amount.paisa <= 0) return false;

    final now = DateTime.now();
    final income = HissaIncome(
      id: 'i_${genId(8)}',
      spaceId: s.id,
      cycleId: cycle.id,
      receivedByUserId: receivedByUserId,
      amount: amount,
      categoryId: categoryId,
      description: description.trim().isEmpty
          ? 'Hissa income'
          : description.trim(),
      date: date,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      participantIds: participantIds,
      splitType: splitType,
      percentages: percentages,
      customAmounts: customAmounts,
      shareUnits: shareUnits,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.saveHissaIncome(income);
    await _notifyHissaIncomeChanged(income, updated: false);
    await _commit();
    return true;
  }

  /// Updates an existing hissa income record. Balances, proposals and
  /// outstanding dues are derived, so they refresh automatically.
  Future<bool> updateHissaIncome(
    HissaIncome income, {
    required String description,
    required Money amount,
    required DateTime date,
    required String receivedByUserId,
    String? categoryId,
    String? note,
    required List<String> participantIds,
    SplitType splitType = SplitType.equal,
    Map<String, double> percentages = const {},
    Map<String, Money> customAmounts = const {},
    Map<String, int> shareUnits = const {},
  }) async {
    final s = space;
    if (s == null || income.spaceId != s.id) return false;
    if (!_incomePartiesAreValid(participantIds)) return false;
    if (!_incomePartiesAreValid([receivedByUserId])) return false;
    if (amount.paisa <= 0) return false;

    final updated = income.copyWith(
      description: description.trim().isEmpty
          ? 'Hissa income'
          : description.trim(),
      amount: amount,
      date: date,
      receivedByUserId: receivedByUserId,
      categoryId: categoryId,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      participantIds: participantIds,
      splitType: splitType,
      percentages: percentages,
      customAmounts: customAmounts,
      shareUnits: shareUnits,
    );
    await _repo.saveHissaIncome(updated);
    await _notifyHissaIncomeChanged(updated, updated: true);
    await _commit();
    return true;
  }

  /// Deletes a hissa income record. Balances are recalculated from the
  /// remaining records automatically.
  Future<void> deleteHissaIncome(String incomeId) async {
    await _repo.deleteHissaIncome(incomeId);
    await _commit();
  }

  /// Notifies every other Space member that hissa income was added or
  /// updated (mirrors the expense notification flow).
  Future<void> _notifyHissaIncomeChanged(
    HissaIncome income, {
    required bool updated,
  }) async {
    final actorId = _currentUserId;
    for (final m in members) {
      if (m.userId == actorId) continue;
      await _saveNotificationFor(
        recipientId: m.userId,
        type: updated
            ? NotificationType.hissaIncomeUpdated
            : NotificationType.hissaIncomeAdded,
        eventKey: income.id,
        spaceId: income.spaceId,
        extra: {
          'hissaIncomeId': income.id,
          'spaceId': income.spaceId,
          'amount': income.amount.paisa,
        },
      );
    }
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
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Settlement requests in the current cycle that still await the creditor's
  /// decision, newest first.
  List<Settlement> get pendingSettlementRequests =>
      settlementsInCycle.where((s) => s.status.awaitsDecision).toList();

  /// Resolved settlements of the current cycle (approved/settled or
  /// rejected), newest first.
  List<Settlement> get resolvedSettlements =>
      settlementsInCycle.where((s) => !s.status.awaitsDecision).toList();

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
      incomes: _repo.hissaIncomes,
    );
    return entries
        .map(
          (e) => BalanceInfo(
            userId: e.id,
            paid: e.paid,
            share: e.share,
            balance: e.balance,
            incomeReceived: e.incomeReceived,
            incomeShare: e.incomeShare,
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

  /// The active Member Group the current user belongs to, if any. A grouped
  /// user's balances are carried by their group, never individually.
  MemberGroup? get currentUserGroup {
    final uid = currentUser?.id;
    if (uid == null) return null;
    return activeMemberGroups
        .where((g) => g.allUserIds.contains(uid))
        .firstOrNull;
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

  /// The Spaces the current user requested to join and is awaiting approval
  /// for. These are NOT membership Spaces: the user cannot open them yet, so
  /// they are kept separate from [_spaces] and must never be selectable.
  List<Space> get pendingSpaces => _pendingSpaces;

  /// Whether [spaceId] is a Space the current user is awaiting approval to
  /// join (i.e. not enterable yet).
  bool isPendingSpace(String spaceId) =>
      _pendingSpaces.any((s) => s.id == spaceId);

  // ---- in-app notification inbox ----

  /// The signed-in user's notification inbox, newest first. Fed in real time by
  /// the repository's `notifications` listener (independent of Space selection).
  List<AppNotification> get notifications {
    final list = _repo.notifications.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// The timestamp after which notifications count as unread. Persisted so the
  /// badge survives relaunches.
  DateTime get notificationsReadAt =>
      _notificationsReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  int get unreadNotificationCount => notifications
      .where((n) => n.createdAt.isAfter(notificationsReadAt))
      .length;

  /// Marks every notification currently in the inbox as read.
  Future<void> markNotificationsRead() async {
    _notificationsReadAt = DateTime.now();
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    await prefs.setString(
      _notificationsReadKey,
      _notificationsReadAt!.toIso8601String(),
    );
  }

  /// Persists a notification into [recipientId]'s inbox. No-op when there is no
  /// signed-in actor, or when the recipient is the actor themselves. The doc id
  /// is deterministic (`recipientId + eventKey`) so a re-run of the same event
  /// overwrites instead of stacking duplicates.
  Future<void> _saveNotificationFor({
    required String recipientId,
    required NotificationType type,
    required String eventKey,
    String? spaceId,
    Map<String, dynamic> extra = const {},
  }) async {
    final actorId = _currentUserId;
    if (actorId == null || recipientId.isEmpty || recipientId == actorId) {
      return;
    }
    final me = currentUser;
    final actorName = me?.name.isNotEmpty == true
        ? me!.name
        : (memberName(actorId) ?? 'A member');
    // Notifications are best-effort side-effects: a denied or failed write must
    // never break the action that triggered it (e.g. approving a join request).
    try {
      await _repo.saveNotification(
        AppNotification(
          id: '${recipientId}_$eventKey',
          userId: recipientId,
          spaceId: spaceId ?? _spaceId,
          type: type,
          eventKey: eventKey,
          actorUserId: actorId,
          actorName: actorName,
          createdAt: DateTime.now(),
          extra: extra,
        ),
      );
    } catch (_) {
      // Swallow: the inbox is an enhancement, not a dependency of the flow.
    }
  }

  /// Notifies every other Space member that an expense was added or updated.
  Future<void> _notifyExpenseChanged(
    Expense expense, {
    required bool updated,
  }) async {
    final actorId = _currentUserId;
    for (final m in members) {
      if (m.userId == actorId) continue;
      await _saveNotificationFor(
        recipientId: m.userId,
        type: updated
            ? NotificationType.expenseUpdated
            : NotificationType.expenseAdded,
        eventKey: expense.id,
        spaceId: expense.spaceId,
        extra: {
          'expenseId': expense.id,
          'spaceId': expense.spaceId,
          'amount': expense.amount.paisa,
        },
      );
    }
  }

  /// Re-queries the current user's pending join requests (Firestore) and
  /// resolves each pending Space's name so the join screen and the Spaces
  /// dashboard can show the requested Spaces without letting the user open
  /// them before the owner approves the request.
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
      final pendingSpaces = <Space>[];
      for (final r in requests) {
        final space = await _repo.fetchSpaceById(r.spaceId);
        if (space != null) pendingSpaces.add(space);
      }
      _pendingSpaces = pendingSpaces;
      notifyListeners();

      if (resolved.isEmpty) return const [];
      final userSpaces = await _repo.findSpacesForUser(uid);
      final newlyApproved = userSpaces
          .where((s) => resolved.contains(s.id))
          .toList();
      // Bring newly approved Spaces into the membership list so the Spaces
      // dashboard and [selectSpace] can see them without a full re-sign-in.
      if (newlyApproved.isNotEmpty) {
        _spaces = userSpaces;
        notifyListeners();
      }
      return newlyApproved;
    } catch (_) {
      notifyListeners();
      return const [];
    }
  }

  /// Universal pull-to-refresh entry point. Re-queries the user's membership
  /// Spaces and pending join requests, and — when running against Firestore —
  /// reloads the currently selected Space's data by re-attaching the
  /// repository. Safe in tests: with an [InMemoryRepository] it only refreshes
  /// the membership lists.
  Future<void> refresh() async {
    await refreshSpaces();
    await refreshPendingSpaceJoinRequests();
    if (_repo is FirestoreRepository &&
        _currentUserId != null &&
        _spaceId != null) {
      await _attachRepository();
    }
  }

  /// Re-queries the user's membership Spaces so the dashboard reflects newly
  /// approved joins and removed memberships without a full re-sign-in.
  Future<void> refreshSpaces() async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      _spaces = await _repo.findSpacesForUser(uid);
      notifyListeners();
    } catch (_) {
      // Keep the previous list on failure.
    }
  }

  /// The display name of a Space by id, resolved from the known member Spaces
  /// first and then the Spaces awaiting approval.
  String? spaceNameById(String spaceId) {
    final member = _spaces.where((s) => s.id == spaceId).firstOrNull;
    if (member != null) return member.name;
    return _pendingSpaces.where((s) => s.id == spaceId).firstOrNull?.name;
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
    // Notify the Space owner(s) that a group creation request awaits their
    // decision.
    for (final owner in members.where((m) => m.role == MemberRole.owner)) {
      await _saveNotificationFor(
        recipientId: owner.userId,
        type: NotificationType.groupRequested,
        eventKey: request.id,
        spaceId: sid,
        extra: {'spaceId': sid},
      );
    }
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
    await _saveNotificationFor(
      recipientId: request.requesterUserId,
      type: NotificationType.groupApproved,
      eventKey: request.id,
      spaceId: request.spaceId,
      extra: {'spaceId': request.spaceId},
    );
    notifyListeners();
    return group;
  }

  /// Rejects [requestId]. Only the Space owner may reject.
  Future<void> rejectGroupRequest(String requestId) async {
    if (!isOwner) return;
    final request = _repo.groupRequests
        .where((r) => r.id == requestId)
        .firstOrNull;
    await _repo.updateGroupRequestStatus(
      requestId,
      GroupRequestStatus.rejected,
    );
    if (request != null) {
      await _saveNotificationFor(
        recipientId: request.requesterUserId,
        type: NotificationType.groupRejected,
        eventKey: request.id,
        spaceId: request.spaceId,
        extra: {'spaceId': request.spaceId},
      );
    }
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
