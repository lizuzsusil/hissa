import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/money.dart';
import '../logic/splits.dart';
import '../models/models.dart';
import 'firestore_repository.dart';
import 'in_memory_repository.dart';

/// Builds a fully populated demo dataset so the app can be explored
/// immediately. The active cycle (August 2026) mirrors the product spec's
/// worked example, while July 2026 shows a closed cycle with settlements.
InMemoryRepository buildSeedRepository() {
  final repo = InMemoryRepository();

  final now = DateTime.now();
  final createdAt = DateTime(now.year, now.month, 1);

  final ram = User(
    id: 'u_ram',
    name: 'Ram',
    email: 'ram@hissa.app',
    createdAt: DateTime(2026, 6, 1),
  );
  final sita = User(
    id: 'u_sita',
    name: 'Sita',
    email: 'sita@hissa.app',
    createdAt: DateTime(2026, 6, 1),
  );
  final john = User(
    id: 'u_john',
    name: 'John',
    email: 'john@hissa.app',
    createdAt: DateTime(2026, 6, 1),
  );
  repo.saveUser(ram);
  repo.saveUser(sita);
  repo.saveUser(john);

  final household = Household(
    id: 'h_demo',
    name: 'Our Home',
    currency: kDefaultCurrency,
    inviteCode: 'SUNNY9',
    createdAt: createdAt,
  );
  repo.saveHousehold(household);

  repo.saveMember(
    HouseholdMember(
      userId: ram.id,
      name: ram.name,
      role: MemberRole.owner,
      joinedAt: createdAt,
    ),
  );
  repo.saveMember(
    HouseholdMember(
      userId: sita.id,
      name: sita.name,
      role: MemberRole.admin,
      joinedAt: createdAt,
    ),
  );
  repo.saveMember(
    HouseholdMember(
      userId: john.id,
      name: john.name,
      role: MemberRole.member,
      joinedAt: createdAt,
    ),
  );

  final nowCycleStart = DateTime(now.year, now.month, 1);
  final nowCycleEnd = DateTime(now.year, now.month + 1, 0);
  final aug = Cycle(
    id: 'c_aug',
    householdId: household.id,
    name: '${_monthName(nowCycleStart)} ${nowCycleStart.year}',
    startDate: nowCycleStart,
    endDate: nowCycleEnd,
    status: CycleStatus.active,
  );
  repo.saveCycle(aug);

  final jul = Cycle(
    id: 'c_jul',
    householdId: household.id,
    name: 'July 2026',
    startDate: DateTime(2026, 7, 1),
    endDate: DateTime(2026, 7, 31),
    status: CycleStatus.closed,
    closedAt: DateTime(2026, 8, 1),
  );
  repo.saveCycle(jul);

  final categories = _defaultCategories(household.id);
  for (final c in categories) {
    repo.saveCategory(c);
  }

  _seedAugust(repo, household, aug, categories);
  _seedJuly(repo, household, jul, categories);

  return repo;
}

void _seedAugust(
  InMemoryRepository repo,
  Household household,
  Cycle cycle,
  List<Category> categories,
) {
  Money amount(int paisa) => Money(paisa);

  void addExpense({
    required String id,
    required String paidBy,
    required int paisa,
    required String category,
    required String description,
    required int day,
    required List<String> participants,
    SplitType type = SplitType.equal,
    Map<String, double>? percentages,
    Map<String, Money>? custom,
    Map<String, int>? shareUnits,
    String? note,
  }) {
    final expense = Expense(
      id: id,
      householdId: household.id,
      cycleId: cycle.id,
      paidByUserId: paidBy,
      amount: amount(paisa),
      categoryId: category,
      description: description,
      date: DateTime(2026, 8, day),
      note: note,
      createdAt: DateTime(2026, 8, day),
      updatedAt: DateTime(2026, 8, day),
    );
    final shares = SplitCalculator.build(
      expenseId: expense.id,
      amount: expense.amount,
      participantIds: participants,
      type: type,
      percentages: percentages ?? const {},
      customAmounts: custom ?? const {},
      shareUnits: shareUnits ?? const {},
    );
    repo.saveExpense(expense, shares);
  }

  final groceries = categories.firstWhere((c) => c.name == 'Groceries');
  final electricity = categories.firstWhere((c) => c.name == 'Electricity');
  final internet = categories.firstWhere((c) => c.name == 'Internet');
  final rent = categories.firstWhere((c) => c.name == 'Rent');
  final entertainment = categories.firstWhere((c) => c.name == 'Entertainment');
  final transportation = categories.firstWhere(
    (c) => c.name == 'Transportation',
  );
  final medical = categories.firstWhere((c) => c.name == 'Medical');
  final food = categories.firstWhere((c) => c.name == 'Food');

  addExpense(
    id: 'e_aug1',
    paidBy: 'u_ram',
    paisa: 450000,
    category: groceries.id,
    description: 'Weekly groceries',
    day: 2,
    participants: ['u_ram', 'u_sita', 'u_john'],
  );
  addExpense(
    id: 'e_aug2',
    paidBy: 'u_sita',
    paisa: 280000,
    category: electricity.id,
    description: 'Electricity bill',
    day: 3,
    participants: ['u_ram', 'u_sita', 'u_john'],
  );
  addExpense(
    id: 'e_aug3',
    paidBy: 'u_john',
    paisa: 150000,
    category: internet.id,
    description: 'Fiber internet',
    day: 5,
    participants: ['u_ram', 'u_sita', 'u_john'],
  );
  addExpense(
    id: 'e_aug4',
    paidBy: 'u_ram',
    paisa: 3000000,
    category: rent.id,
    description: 'Monthly rent',
    day: 6,
    participants: ['u_ram', 'u_sita', 'u_john'],
  );
  addExpense(
    id: 'e_aug5',
    paidBy: 'u_ram',
    paisa: 120000,
    category: groceries.id,
    description: 'Vegetables',
    day: 7,
    participants: ['u_ram', 'u_sita'],
  );
  addExpense(
    id: 'e_aug6',
    paidBy: 'u_john',
    paisa: 240000,
    category: entertainment.id,
    description: 'Movie night',
    day: 8,
    participants: ['u_ram', 'u_sita', 'u_john'],
  );
  addExpense(
    id: 'e_aug7',
    paidBy: 'u_sita',
    paisa: 200000,
    category: transportation.id,
    description: 'Fuel top-up',
    day: 9,
    participants: ['u_ram', 'u_sita', 'u_john'],
    type: SplitType.percentage,
    percentages: {'u_ram': 50, 'u_sita': 30, 'u_john': 20},
  );
  addExpense(
    id: 'e_aug8',
    paidBy: 'u_ram',
    paisa: 135000,
    category: medical.id,
    description: 'Pharmacy',
    day: 10,
    participants: ['u_ram'],
    note: 'Personal medication',
  );
  addExpense(
    id: 'e_aug9',
    paidBy: 'u_sita',
    paisa: 360000,
    category: food.id,
    description: 'Dinner with friends',
    day: 11,
    participants: ['u_ram', 'u_sita', 'u_john'],
    type: SplitType.shares,
    shareUnits: {'u_ram': 1, 'u_sita': 2, 'u_john': 1},
  );
}

void _seedJuly(
  InMemoryRepository repo,
  Household household,
  Cycle cycle,
  List<Category> categories,
) {
  Money amount(int paisa) => Money(paisa);

  final groceries = categories.firstWhere((c) => c.name == 'Groceries');
  final electricity = categories.firstWhere((c) => c.name == 'Electricity');
  final internet = categories.firstWhere((c) => c.name == 'Internet');
  final rent = categories.firstWhere((c) => c.name == 'Rent');
  final food = categories.firstWhere((c) => c.name == 'Food');

  void addExpense({
    required String id,
    required String paidBy,
    required int paisa,
    required String category,
    required String description,
    required int day,
  }) {
    final expense = Expense(
      id: id,
      householdId: household.id,
      cycleId: cycle.id,
      paidByUserId: paidBy,
      amount: amount(paisa),
      categoryId: category,
      description: description,
      date: DateTime(2026, 7, day),
      createdAt: DateTime(2026, 7, day),
      updatedAt: DateTime(2026, 7, day),
    );
    final shares = SplitCalculator.build(
      expenseId: expense.id,
      amount: expense.amount,
      participantIds: ['u_ram', 'u_sita'],
    );
    repo.saveExpense(expense, shares);
  }

  addExpense(
    id: 'e_jul1',
    paidBy: 'u_ram',
    paisa: 3000000,
    category: rent.id,
    description: 'Monthly rent',
    day: 3,
  );
  addExpense(
    id: 'e_jul2',
    paidBy: 'u_sita',
    paisa: 650000,
    category: groceries.id,
    description: 'Groceries',
    day: 7,
  );
  addExpense(
    id: 'e_jul3',
    paidBy: 'u_ram',
    paisa: 150000,
    category: internet.id,
    description: 'Fiber internet',
    day: 12,
  );
  addExpense(
    id: 'e_jul4',
    paidBy: 'u_ram',
    paisa: 420000,
    category: food.id,
    description: 'Restaurant',
    day: 20,
  );
  addExpense(
    id: 'e_jul5',
    paidBy: 'u_sita',
    paisa: 360000,
    category: electricity.id,
    description: 'Electricity bill',
    day: 25,
  );

  repo.saveSettlement(
    Settlement(
      id: 's_jul1',
      householdId: household.id,
      cycleId: cycle.id,
      fromUserId: 'u_sita',
      toUserId: 'u_ram',
      amount: amount(1280000),
      currency: household.currency,
      paymentMethod: 'Bank Transfer',
      date: DateTime(2026, 7, 31),
      status: SettlementStatus.paid,
      createdAt: DateTime(2026, 7, 31),
    ),
  );
}

List<Category> _defaultCategories(String householdId) {
  return kDefaultCategories
      .map(
        (preset) => Category.preset(
          id: 'cat_${preset.name.toLowerCase()}',
          householdId: householdId,
          name: preset.name,
          icon: preset.icon,
          color: preset.color,
        ),
      )
      .toList();
}

String _monthName(DateTime d) {
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

/// Writes the demo dataset to Firestore for the "explore the demo" login.
/// The demo household is signed in anonymously, so the seeded owner (Ram,
/// `u_ram`) is remapped to the anonymous user's [uid] so security rules treat
/// them as a member of `h_demo`.
Future<void> seedDemoFirestore(FirebaseFirestore db, String uid) async {
  final seed = buildSeedRepository();
  final data = _remapDemo(seed, uid);
  await FirestoreRepository(db).writeAll(
    users: data.users,
    households: data.households,
    members: data.members,
    membersHouseholdId: 'h_demo',
    cycles: data.cycles,
    expenses: data.expenses,
    shares: data.shares,
    settlements: data.settlements,
    categories: data.categories,
  );
}

class _DemoData {
  final List<User> users;
  final List<Household> households;
  final List<HouseholdMember> members;
  final List<Cycle> cycles;
  final List<Expense> expenses;
  final List<ExpenseShare> shares;
  final List<Settlement> settlements;
  final List<Category> categories;

  const _DemoData({
    required this.users,
    required this.households,
    required this.members,
    required this.cycles,
    required this.expenses,
    required this.shares,
    required this.settlements,
    required this.categories,
  });
}

_DemoData _remapDemo(InMemoryRepository seed, String uid) {
  String map(String id) => id == 'u_ram' ? uid : id;

  final users = seed.users.map((u) {
    if (u.id == 'u_ram') {
      return User(
        id: uid,
        name: u.name,
        email: u.email,
        phone: u.phone,
        avatarUrl: u.avatarUrl,
        createdAt: u.createdAt,
      );
    }
    return u;
  }).toList();

  final members = seed.members
      .map(
        (m) => HouseholdMember(
          userId: map(m.userId),
          name: m.name,
          role: m.role,
          joinedAt: m.joinedAt,
          avatarUrl: m.avatarUrl,
        ),
      )
      .toList();

  final expenses = seed.expenses
      .map((e) => e.copyWith(paidByUserId: map(e.paidByUserId)))
      .toList();

  final shares = seed.shares
      .map(
        (s) => ExpenseShare(
          id: s.id,
          expenseId: s.expenseId,
          userId: map(s.userId),
          amount: s.amount,
          percentage: s.percentage,
          shares: s.shares,
        ),
      )
      .toList();

  final settlements = seed.settlements
      .map(
        (s) => Settlement(
          id: s.id,
          householdId: s.householdId,
          cycleId: s.cycleId,
          fromUserId: map(s.fromUserId),
          toUserId: map(s.toUserId),
          amount: s.amount,
          currency: s.currency,
          paymentMethod: s.paymentMethod,
          date: s.date,
          note: s.note,
          status: s.status,
          createdAt: s.createdAt,
        ),
      )
      .toList();

  return _DemoData(
    users: users,
    households: seed.households.toList(),
    members: members,
    cycles: seed.cycles.toList(),
    expenses: expenses,
    shares: shares,
    settlements: settlements,
    categories: seed.categories.toList(),
  );
}
