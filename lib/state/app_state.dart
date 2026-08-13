import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/foundation.dart' show kIsWeb;
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

/// Ensures [GoogleSignIn.instance] is initialized exactly once.
bool _googleInitialized = false;

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

  ExpenseRepository get repo => _repo;
  bool get isLoaded => _loaded;
  String? get onboardingMode => _onboardingMode;
  String? get currentUserId => _currentUserId;
  bool get isLoggedIn => _currentUserId != null;
  bool get hasSpace => _spaceId != null;
  bool get introSeen => _introSeen;

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
        spaceId = json['householdId'] as String?; // legacy key name kept for compat
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
        'householdId': _spaceId, // legacy key name kept for session compat
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
  Future<void> _attachRepository() async {
    final uid = _currentUserId;
    if (uid == null) return;
    if (_repo is FirestoreRepository) {
      (_repo as FirestoreRepository).stop();
    }

    final repo = FirestoreRepository(FirebaseFirestore.instance);
    List<Space> spaces = const [];
    try {
      spaces = await repo.findSpacesForUser(uid);
    } catch (_) {
      spaces = const [];
    }
    _spaces = spaces;

    if (spaces.isEmpty) {
      _spaceId = null;
      _cycleId = null;
    } else {
      final stillMember = _spaceId != null &&
          spaces.any((s) => s.id == _spaceId);
      if (!stillMember) {
        _spaceId = spaces.first.id;
        _cycleId = null;
      }
    }
    _repo = repo;
    await repo.start(uid: uid, spaceId: _spaceId, onChanged: notifyListeners);
    await _runLegacyMigration();
  }

  /// Phase 7: one-time legacy data migration. Idempotent — it only rewrites
  /// Spaces that still lack an explicit mode and never touches legacy
  /// expenses (ambiguous ones stay read-only historical records).
  Future<void> _runLegacyMigration() async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      final report =
          await SpaceMigrator().run(_repo, userId: uid);
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

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
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
        cred = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
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
    final displayName = name.trim().isEmpty
        ? _capitalize(normalized.split('@').first)
        : name.trim();
    await _repo.saveUser(
      User(id: uid, name: displayName, email: normalized, createdAt: DateTime.now()),
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
    try {
      await FirebaseAuth.instance.signOut();
    } on Exception {
      // Local session is cleared regardless.
    }
    await _commit();
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
    final all =
        _repo.cycles.where((c) => c.householdId == _spaceId).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return all;
  }

  Cycle? get activeCycle {
    if (_spaceId == null) return null;
    final active = _repo.cycles
        .where(
          (c) =>
              c.householdId == _spaceId && c.status == CycleStatus.active,
        )
        .firstOrNull;
    if (active != null) return active;
    return _repo.cycles
        .where((c) => c.householdId == _spaceId)
        .toList()
        .lastOrNull;
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
    _spaceId = spaceId;
    _cycleId = null;
    await _attachRepository();
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
    return _repo.categories
        .where((c) => c.householdId == _spaceId)
        .toList();
  }

  // ---- space ----

  Future<bool> createSpace({
    required String name,
    required String currency,
    required List<String> memberNames,
    required SpaceMode mode,
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
    );
    // The owner membership is written before the Space so security rules
    // (which gate Space writes on membership) accept the create.
    await _repo.saveMember(
      SpaceMember(
        userId: user.id,
        name: user.name,
        role: MemberRole.owner,
        joinedAt: DateTime.now(),
      ),
      spaceId,
    );
    await _repo.saveSpace(space);

    for (final memberName in memberNames) {
      final trimmed = memberName.trim();
      if (trimmed.isEmpty) continue;
      if (_repo.members.any((m) => m.name == trimmed)) continue;
      final newUser = User(
        id: 'u_${genId(8)}',
        name: trimmed,
        email:
            '${trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@hissa.app',
        createdAt: DateTime.now(),
      );
      await _repo.saveUser(newUser);
      await _repo.saveMember(
        SpaceMember(
          userId: newUser.id,
          name: trimmed,
          role: MemberRole.member,
          joinedAt: DateTime.now(),
        ),
        spaceId,
      );
    }

    await _seedCategories(spaceId);
    if (mode != SpaceMode.solo) {
      await _startCycleFor(spaceId, DateTime.now());
    }

    _spaceId = spaceId;
    _cycleId = null;
    await _attachRepository();
    await _commit();
    return true;
  }

  Future<bool> joinSpace(String code) async {
    final user = currentUser;
    if (user == null) return false;
    final normalized = code.trim().toUpperCase();
    final space = await _repo.findSpaceByInviteCode(normalized);
    if (space == null) return false;

    if (!_repo.members.any((m) => m.userId == user.id)) {
      await _repo.saveMember(
        SpaceMember(
          userId: user.id,
          name: user.name,
          role: MemberRole.member,
          joinedAt: DateTime.now(),
        ),
        space.id,
      );
    }
    _spaceId = space.id;
    _cycleId = null;
    await _attachRepository();
    await _commit();
    return true;
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

  Future<void> addMember(String name) async {
    final s = space;
    if (s == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_repo.members.any(
      (m) => m.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      return;
    }
    final newUser = User(
      id: 'u_${genId(8)}',
      name: trimmed,
      email:
          '${trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@hissa.app',
      createdAt: DateTime.now(),
    );
    await _repo.saveUser(newUser);
    await _repo.saveMember(
      SpaceMember(
        userId: newUser.id,
        name: trimmed,
        role: MemberRole.member,
        joinedAt: DateTime.now(),
      ),
      s.id,
    );
    await _commit();
  }

  Future<void> removeMember(String userId) async {
    if (userId == currentUser?.id) return;
    await _repo.removeMember(userId, _spaceId ?? '');
    await _commit();
  }

  // ---- categories ----

  Future<void> addCategory(String name, IconData icon, Color color) async {
    final s = space;
    if (s == null) return;
    await _repo.saveCategory(
      Category(
        id: 'cat_${genId(8)}',
        householdId: s.id,
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
          householdId: spaceId,
          name: preset.name,
          icon: preset.icon,
          color: preset.color,
        ),
      );
    }
  }

  // ---- cycles ----

  Future<void> _startCycleFor(String spaceId, DateTime anchor) async {
    final start = DateTime(anchor.year, anchor.month, 1);
    final end = DateTime(anchor.year, anchor.month + 1, 0);
    final existing = _repo.cycles
        .where(
          (c) =>
              c.householdId == spaceId &&
              c.startDate.year == start.year &&
              c.startDate.month == start.month,
        )
        .firstOrNull;
    if (existing != null) return;
    await _repo.saveCycle(
      Cycle(
        id: 'c_${genId(8)}',
        householdId: spaceId,
        name: '${_monthLabel(start)} ${start.year}',
        startDate: start,
        endDate: end,
        status: CycleStatus.active,
      ),
    );
  }

  Future<void> closeCycle() async {
    final cycle = selectedCycle;
    if (cycle == null) return;
    final balances = computeBalances(cycle.id);
    final hasOutstanding = balances.any((b) => !b.remaining.isZero);
    if (hasOutstanding) return;
    await _repo.saveCycle(
      cycle.copyWith(status: CycleStatus.closed, closedAt: DateTime.now()),
    );
    await _commit();
  }

  Future<void> startNewCycle() async {
    final s = space;
    final cycle = selectedCycle;
    if (s == null) return;
    final anchor = DateTime.now();
    if (cycle != null && cycle.status == CycleStatus.active) {
      await _repo.saveCycle(
        cycle.copyWith(status: CycleStatus.closed, closedAt: DateTime.now()),
      );
    }
    await _startCycleFor(s.id, anchor);
    _cycleId = null;
    await _commit();
  }

  // ---- expenses ----

  /// Builds disjoint split parties from the selected participant ids plus any
  /// participant groups. Users inside a group form one party; every other
  /// selected user is an individual party.
  List<SplitParty> _partiesFrom({
    required List<String> participantIds,
    required List<ParticipantGroup> groups,
  }) {
    final grouped = <String>{for (final g in groups) ...g.userIds};
    return [
      for (final id in participantIds)
        if (!grouped.contains(id)) SplitParty.individual(id),
      for (final g in groups)
        SplitParty(id: g.id, name: g.name, userIds: g.userIds),
    ];
  }

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

  Future<void> addExpense({
    required String description,
    required Money amount,
    required DateTime date,
    String? categoryId,
    String? note,
    required List<String> participantIds,
    List<ParticipantGroup> groups = const [],
    SplitType splitType = SplitType.equal,
    Map<String, double> percentages = const {},
    Map<String, Money> customAmounts = const {},
    Map<String, int> shareUnits = const {},
  }) async {
    final s = space;
    final cycle = selectedCycle;
    if (s == null || cycle == null) return;
    if (!_participantsAreMembers(participantIds, groups)) return;
    final expenseId = 'e_${genId(8)}';
    final expense = Expense(
      id: expenseId,
      householdId: s.id,
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
    final shares = SplitCalculator.buildGrouped(
      expenseId: expense.id,
      amount: expense.amount,
      parties: _partiesFrom(
        participantIds: participantIds,
        groups: groups,
      ),
      type: splitType,
      percentages: percentages,
      customAmounts: customAmounts,
      shareUnits: shareUnits,
    );
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
    SplitType splitType = SplitType.equal,
    Map<String, double> percentages = const {},
    Map<String, Money> customAmounts = const {},
    Map<String, int> shareUnits = const {},
  }) async {
    if (!canEditExpense(expense)) return;
    if (!_participantsAreMembers(participantIds, groups)) return;
    final updated = expense.copyWith(
      description: description.trim().isEmpty ? 'Expense' : description.trim(),
      amount: amount,
      date: date,
      categoryId: categoryId,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      participantGroups: _bindGroups(groups, expense.id),
    );
    final shares = SplitCalculator.buildGrouped(
      expenseId: expense.id,
      amount: updated.amount,
      parties: _partiesFrom(
        participantIds: participantIds,
        groups: groups,
      ),
      type: splitType,
      percentages: percentages,
      customAmounts: customAmounts,
      shareUnits: shareUnits,
    );
    await _repo.saveExpense(updated, shares);
    await _commit();
  }

  Future<void> deleteExpense(String expenseId) async {
    final expense =
        _repo.expenses.where((e) => e.id == expenseId).firstOrNull;
    if (expense == null || !canEditExpense(expense)) return;
    await _repo.deleteExpense(expenseId);
    await _commit();
  }

  // ---- personal expenses (solo / personal mode) ----

  /// Whether the selected Space is a Personal (solo) space.
  bool get isPersonalMode {
    final s = space;
    return s != null && s.mode == SpaceMode.solo;
  }

  /// Personal expenses: those created without a cycle (cycleId == null) in
  /// the selected Space, most recent first.
  List<Expense> get personalExpenses {
    if (_spaceId == null) return const [];
    final list = _repo.expenses
        .where((e) => e.householdId == _spaceId && e.cycleId == null)
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
      householdId: s.id,
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
        householdId: s.id,
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
  bool canEditExpense(Expense expense) => canEditExpenseBy(
        currentUserId: _currentUserId,
        expense: expense,
      );

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
    return BalanceCalculator.compute(
      space: s,
      members: members,
      cycle: cycle,
      expenses: _repo.expenses,
      shares: _repo.shares,
      settlements: _repo.settlements,
    );
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

  String? memberName(String userId) =>
      members.where((m) => m.userId == userId).firstOrNull?.name;

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
