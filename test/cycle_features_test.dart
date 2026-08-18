import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hissa/models/models.dart';
import 'package:hissa/state/app_state.dart';

const _months = [
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

/// Cycle type / cycle lifecycle rules: monthly vs custom scheduling, owner-only
/// close/start/rename, monthly rollover and cycle-type persistence.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<AppState> makeState({String userId = 'u_owner'}) async {
    final state = AppState();
    final repo = state.repo;
    await repo.saveUser(
      User(
        id: 'u_owner',
        name: 'Owner',
        email: 'owner@example.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveUser(
      User(
        id: 'u_b',
        name: 'B',
        email: 'b@example.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u_owner',
        name: 'Owner',
        role: MemberRole.owner,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    await repo.saveMember(
      SpaceMember(
        userId: 'u_b',
        name: 'B',
        role: MemberRole.member,
        joinedAt: DateTime(2026, 1, 1),
        spaceId: 'h1',
      ),
      'h1',
    );
    state.debugSetSession(userId: userId, spaceId: 'h1');
    return state;
  }

  Future<Space> seedSpace(AppState state, {CycleType cycleType = CycleType.monthly}) async {
    final space = Space(
      id: 'h1',
      name: 'Home',
      currency: 'NPR',
      inviteCode: 'ABCD12',
      mode: SpaceMode.split,
      cycleType: cycleType,
      createdAt: DateTime(2026, 1, 1),
    );
    await state.repo.saveSpace(space);
    return space;
  }

  test('starting a custom cycle names it "Cycle 1"', () async {
    final state = await makeState();
    await seedSpace(state, cycleType: CycleType.custom);
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');

    await state.startNewCycle();
    final active = state.activeCycle;
    expect(active, isNotNull);
    expect(active!.name, 'Cycle 1');
    expect(active.status, CycleStatus.active);
  });

  test('starting a monthly cycle names it after the running month', () async {
    final state = await makeState();
    await seedSpace(state, cycleType: CycleType.monthly);
    await state.repo.saveCycle(
      Cycle(
        id: 'c_past',
        spaceId: 'h1',
        name: 'January 2026',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        status: CycleStatus.active,
      ),
    );
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');

    await state.startNewCycle();

    final now = DateTime.now();
    final expected = '${_months[now.month - 1]} ${now.year}';
    expect(state.activeCycle?.name, expected);
    expect(state.activeCycle?.status, CycleStatus.active);
  });

  test('cycleType round-trips through Space persistence', () {
    final json = {
      'id': 'h1',
      'name': 'Home',
      'currency': 'NPR',
      'inviteCode': 'ABCD12',
      'mode': 'SPLIT',
      'cycleType': 'CUSTOM',
      'createdAt': '2026-01-01T00:00:00.000',
    };
    final parsed = Space.fromJson(json);
    expect(parsed.cycleType, CycleType.custom);

    final legacy = Map<String, dynamic>.from(json)..remove('cycleType');
    expect(Space.fromJson(legacy).cycleType, CycleType.monthly);
  });

  test('closing and starting cycles requires the owner', () async {
    final state = await makeState();
    await seedSpace(state);
    final now = DateTime.now();
    await state.repo.saveCycle(
      Cycle(
        id: 'c1',
        spaceId: 'h1',
        name: '${_months[now.month - 1]} ${now.year}',
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
        status: CycleStatus.active,
      ),
    );

    // A regular member cannot close or start cycles.
    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    await state.closeCycle();
    expect(state.activeCycle?.status, CycleStatus.active);
    await state.startNewCycle();
    expect(state.activeCycle?.status, CycleStatus.active);

    // The owner can.
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    await state.closeCycle();
    expect(state.activeCycle?.status, CycleStatus.closed);
  });

  test('renameCycle is owner-only', () async {
    final state = await makeState();
    await seedSpace(state, cycleType: CycleType.custom);
    await state.repo.saveCycle(
      Cycle(
        id: 'c1',
        spaceId: 'h1',
        name: 'Cycle 1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 1),
        status: CycleStatus.active,
      ),
    );

    state.debugSetSession(userId: 'u_b', spaceId: 'h1');
    expect(await state.renameCycle('c1', 'Holiday Trip'), isFalse);

    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');
    expect(await state.renameCycle('c1', 'Holiday Trip'), isTrue);
    expect(state.cycles.first.name, 'Holiday Trip');
  });

  test('starting a new custom cycle names it sequentially', () async {
    final state = await makeState();
    await seedSpace(state, cycleType: CycleType.custom);
    await state.repo.saveCycle(
      Cycle(
        id: 'c1',
        spaceId: 'h1',
        name: 'Cycle 1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 1),
        status: CycleStatus.active,
      ),
    );
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');

    await state.closeCycle();
    expect(state.closedCycles.length, 1);

    await state.startNewCycle();
    final newCycle = state.activeCycle;
    expect(newCycle, isNotNull);
    expect(newCycle!.name, 'Cycle 2');
    expect(state.closedCycles.length, 1);
  });

  test('monthly rollover closes a past-month cycle and opens the current month',
      () async {
    final state = await makeState();
    await seedSpace(state, cycleType: CycleType.monthly);
    await state.repo.saveCycle(
      Cycle(
        id: 'c_past',
        spaceId: 'h1',
        name: 'January 2026',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        status: CycleStatus.active,
      ),
    );
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');

    await state.debugRunMonthlyRollover();

    final now = DateTime.now();
    final expected = '${_months[now.month - 1]} ${now.year}';
    expect(state.activeCycle?.name, expected);
    expect(state.activeCycle?.status, CycleStatus.active);
    expect(state.closedCycles.map((c) => c.name), contains('January 2026'));
  });

  test('custom spaces never roll over automatically', () async {
    final state = await makeState();
    await seedSpace(state, cycleType: CycleType.custom);
    await state.repo.saveCycle(
      Cycle(
        id: 'c1',
        spaceId: 'h1',
        name: 'Cycle 1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 1),
        status: CycleStatus.active,
      ),
    );
    state.debugSetSession(userId: 'u_owner', spaceId: 'h1');

    await state.debugRunMonthlyRollover();

    expect(state.activeCycle?.name, 'Cycle 1');
    expect(state.closedCycles, isEmpty);
  });
}
