// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hissa';

  @override
  String get tagline => 'All your expenses, in one place';

  @override
  String get home => 'Home';

  @override
  String get expenses => 'Expenses';

  @override
  String get settle => 'Settle';

  @override
  String get insights => 'Insights';

  @override
  String get settings => 'Settings';

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get continueLabel => 'Continue';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get getStarted => 'Get started';

  @override
  String get apply => 'Apply';

  @override
  String get review => 'Review';

  @override
  String get viewAll => 'View all';

  @override
  String get all => 'All';

  @override
  String get cycle => 'Cycle';

  @override
  String get even => 'Even';

  @override
  String get you => 'You';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get ok => 'OK';

  @override
  String get general => 'General';

  @override
  String get unknown => 'Unknown';

  @override
  String get attached => 'Attached';

  @override
  String get other => 'Other';

  @override
  String get expense => 'Expense';

  @override
  String settlementsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count settlements waiting',
      one: '1 settlement waiting',
    );
    return '$_temp0';
  }

  @override
  String splitPersons(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String expensesAndTotal(int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses · $total',
      one: '1 expense · $total',
    );
    return '$_temp0';
  }

  @override
  String memberPaidShare(String paid, String share) {
    return 'Paid $paid · Share $share';
  }

  @override
  String paidByMemberDay(String name, String day) {
    return '$name paid · $day';
  }

  @override
  String owes(String from, String to) {
    return '$from owes $to';
  }

  @override
  String fromTo(String from, String to) {
    return '$from → $to';
  }

  @override
  String settlementMethodDay(String method, String day) {
    return '$method · $day';
  }

  @override
  String memberJoinedDate(String role, String date) {
    return '$role · Joined $date';
  }

  @override
  String cycleNameByCategory(String name) {
    return '$name by category';
  }

  @override
  String addedMember(String name) {
    return '$name added to the household';
  }

  @override
  String removeMemberTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String closeCycleTitle(String name) {
    return 'Close $name?';
  }

  @override
  String householdMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get category => 'Category';

  @override
  String get amount => 'Amount';

  @override
  String get description => 'Description';

  @override
  String get descriptionHint => 'What was this for?';

  @override
  String get paidBy => 'Paid by';

  @override
  String get date => 'Date';

  @override
  String get splitBetween => 'Split between';

  @override
  String get note => 'Note';

  @override
  String get noteOptionalHint => 'Add a note (optional)';

  @override
  String get splitPreview => 'Split preview';

  @override
  String get total => 'Total';

  @override
  String get selectParticipant => 'Select at least one participant.';

  @override
  String get splitLabelEqual => 'Equal';

  @override
  String get splitLabelPercent => 'Percent';

  @override
  String get splitLabelAmounts => 'Amounts';

  @override
  String get splitLabelShares => 'Shares';

  @override
  String get assigned => 'Assigned';

  @override
  String get totalShares => 'Total shares';

  @override
  String get createGroup => 'Create group';

  @override
  String get ungroup => 'Remove group';

  @override
  String get selectGroupMembers => 'Choose members to group together';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get addExpense => 'Add expense';

  @override
  String get yourBalance => 'Your balance';

  @override
  String get youPaid => 'You paid';

  @override
  String get yourShare => 'Your share';

  @override
  String get youReceive => 'You receive';

  @override
  String get youOwe => 'You owe';

  @override
  String get totalSpending => 'Total spending';

  @override
  String get householdBalances => 'Household balances';

  @override
  String get recentExpenses => 'Recent expenses';

  @override
  String get thisMonth => 'This month';

  @override
  String get lastMonth => 'Last month';

  @override
  String vsMonth(Object month) {
    return 'vs $month';
  }

  @override
  String get noExpensesYet => 'No expenses yet';

  @override
  String get noExpensesMessage =>
      'Tap the + button to add your first shared expense.';

  @override
  String get settleUp => 'Settle up';

  @override
  String get searchExpenses => 'Search expenses';

  @override
  String get filterExpenses => 'Filter expenses';

  @override
  String get everyone => 'Everyone';

  @override
  String get noMatchingExpenses => 'No matching expenses';

  @override
  String get noMatchingMessage =>
      'Try a different search or filter, or add a new expense.';

  @override
  String get expenseDetails => 'Expense details';

  @override
  String get split => 'Split';

  @override
  String get receipt => 'Receipt';

  @override
  String get whoPaysWhat => 'Who pays what';

  @override
  String get paid => 'Paid';

  @override
  String get cycleClosedHint =>
      'This cycle is closed, so expenses can no longer be edited.';

  @override
  String get deleteExpenseTitle => 'Delete this expense?';

  @override
  String get deleteExpenseMessage =>
      'Deleting an expense changes the current household balances for everyone.';

  @override
  String get monthlySpending => 'Monthly spending';

  @override
  String get whoPaidThisCycle => 'Who paid this cycle';

  @override
  String get selectCycle => 'Select cycle';

  @override
  String get nothingToChart => 'Nothing to chart yet';

  @override
  String get nothingToChartMessage =>
      'Add expenses to see your spending breakdown.';

  @override
  String get lifetimeSummary => 'Lifetime summary';

  @override
  String get totalSpent => 'Total spent';

  @override
  String get average => 'Average';

  @override
  String get introTitle1 => 'Welcome to Hissa';

  @override
  String get introSubtitle1 =>
      'The simplest way for households, roommates and families to track shared expenses together.';

  @override
  String get introTitle2 => 'Track every expense';

  @override
  String get introSubtitle2 =>
      'Add expenses in seconds. Split bills equally, by percentage or by custom amounts — Hissa keeps the math exact.';

  @override
  String get introTitle3 => 'Settle up fairly';

  @override
  String get introSubtitle3 =>
      'See who owes whom at a glance and record payments with cash, bank transfer, eSewa or Khalti in one tap.';

  @override
  String get introTitle4 => 'Understand your spending';

  @override
  String get introSubtitle4 =>
      'Monthly insights, category breakdowns and one-tap CSV export keep you on top of where the money goes.';

  @override
  String get onboardingTitle => 'How are you\nsharing expenses?';

  @override
  String get onboardingSubtitle =>
      'Pick the setup that matches your household. You can change it anytime.';

  @override
  String get modeTwoPeople => 'Two People';

  @override
  String get modeTwoPeopleSubtitle => 'A couple or duo sharing life and bills';

  @override
  String get modeFamily => 'Family';

  @override
  String get modeFamilySubtitle => 'Parents, kids and the whole household';

  @override
  String get modeRoommates => 'Roommates';

  @override
  String get modeRoommatesSubtitle => 'Flatmates splitting rent and utilities';

  @override
  String get modeOther => 'Other';

  @override
  String get modeOtherSubtitle => 'Any small group sharing expenses';

  @override
  String get setUpHousehold => 'Set up your household';

  @override
  String get setUpSubtitle =>
      'Create a new household or join one with an invite code.';

  @override
  String get create => 'Create';

  @override
  String get join => 'Join';

  @override
  String get householdName => 'Household name';

  @override
  String get householdNameHint => 'e.g. Our Home';

  @override
  String get whoLivesHere => 'Who lives here?';

  @override
  String get addMember => 'Add a member';

  @override
  String get name => 'Name';

  @override
  String get currency => 'Currency';

  @override
  String get createHousehold => 'Create household';

  @override
  String get inviteLater => 'You can invite more people later from Settings';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get inviteCodeHint => 'ABCDE2';

  @override
  String get inviteCodeHelp =>
      'Ask the household owner for their invite code. Codes are shown in Settings → Household.';

  @override
  String get joinHousehold => 'Join household';

  @override
  String get inviteNotFound =>
      'Invite code not found. Check the code and try again.';

  @override
  String get householdNameRequired => 'Household name is required';

  @override
  String get enterMemberNameError => 'Enter a member name';

  @override
  String get duplicateMemberError => 'That name is already in the list';

  @override
  String get enterInviteCodeError => 'Enter the invite code';

  @override
  String get inviteCodeFormatError => 'Invite codes are 6 characters long';

  @override
  String get mySpaces => 'My Spaces';

  @override
  String get mySpacesSubtitle => 'All your expense spaces in one place';

  @override
  String get noSpacesYet => 'No spaces yet';

  @override
  String get noSpacesMessage =>
      'Create a space to start tracking your expenses, or join an existing space.';

  @override
  String get createSpace => 'Create Space';

  @override
  String get joinSpace => 'Join Space';

  @override
  String get switchSpace => 'My Spaces';

  @override
  String get switchSpaceSubtitle => 'Switch between your spaces';

  @override
  String get splitMode => 'Split Mode';

  @override
  String get personalMode => 'Personal Mode';

  @override
  String get spaceName => 'Space name';

  @override
  String get spaceNameHint => 'e.g. Our Home';

  @override
  String get spaceNameRequired => 'Space name is required';

  @override
  String get chooseSpaceMode => 'Choose how you\'ll use it';

  @override
  String get splitModeDescription =>
      'Share expenses, calculate balances and settle up.';

  @override
  String get personalModeDescription =>
      'Track your own spending without splitting or settling.';

  @override
  String get createSpaceTitle => 'Create a Space';

  @override
  String get createSpaceSubtitle =>
      'Name your space and pick how you\'ll use it.';

  @override
  String get createdSpaceTitle => 'Space created';

  @override
  String get joinedSpaceTitle => 'Space joined';

  @override
  String get createAccount => 'Create account';

  @override
  String get logIn => 'Log in';

  @override
  String get createYourAccount => 'Create your account';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get authSignupSubtitle => 'Start tracking shared expenses in seconds.';

  @override
  String get authLoginSubtitle => 'Log in to keep your household in sync.';

  @override
  String get yourName => 'Your name';

  @override
  String get emailAddress => 'Email address';

  @override
  String get password => 'Password';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get or => 'or';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get logInLink => 'Log in';

  @override
  String get newToHissa => 'New to Hissa? ';

  @override
  String get createOne => 'Create one';

  @override
  String get errEmailRequired => 'Email address is required';

  @override
  String get errEmailInvalid => 'Enter a valid email address';

  @override
  String get errPasswordRequired => 'Password is required';

  @override
  String get errPasswordShort => 'Password must be at least 6 characters';

  @override
  String get errPasswordLong => 'Password must be 64 characters or fewer';

  @override
  String get errNameRequired => 'Your name is required';

  @override
  String get errFieldRequired => 'This field is required';

  @override
  String get errTooLong => 'Name must be 40 characters or fewer';

  @override
  String get errIncorrectCredentials =>
      'Incorrect email or password. Try again or create an account.';

  @override
  String get authGoogleConflict =>
      'That email already has a password account. Log in with your email and password instead.';

  @override
  String get authEmailInUse =>
      'An account already exists for that email. Log in instead.';

  @override
  String get authWeakPassword =>
      'That password is too weak. Use at least 6 characters.';

  @override
  String get authInvalidEmail => 'That email address does not look valid.';

  @override
  String get authIncorrect => 'Incorrect email or password.';

  @override
  String get authUserDisabled => 'This account has been disabled.';

  @override
  String get authTooManyRequests =>
      'Too many attempts. Please wait and try again.';

  @override
  String get authNetwork =>
      'No internet connection. Check your connection and retry.';

  @override
  String get authOperationNotAllowed =>
      'This sign-in method is not enabled yet. Enable it in the Firebase console.';

  @override
  String get authConfigError =>
      'Authentication is not configured correctly. Check the Firebase console app config and keys.';

  @override
  String get authFirestoreDenied =>
      'The database is rejecting this action. Publish the firestore.rules file to Firebase.';

  @override
  String get authFirestoreUnavailable =>
      'The database is busy or not ready yet. Please try again.';

  @override
  String get authGoogleConfig =>
      'Google sign-in is not configured yet. Add your Android SHA-1 fingerprint in the Firebase console, then re-run `flutterfire configure`.';

  @override
  String get authGooglePlayServices =>
      'Google Play services is unavailable or misconfigured on this device.';

  @override
  String get authGoogleUi =>
      'The Google sign-in window could not be shown right now. Please try again.';

  @override
  String get authSomethingWentWrong =>
      'Something went wrong. Check the debug logs for the exact error.';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get biometricLogin => 'Log in with biometrics';

  @override
  String get biometricUnavailable =>
      'Biometric authentication is not available on this device.';

  @override
  String get biometricFailed =>
      'Biometric authentication failed. Please try again.';

  @override
  String get biometricNotEnrolled =>
      'No biometrics enrolled. Set up Face ID / Touch ID in Settings.';

  @override
  String get security => 'Security';

  @override
  String get usePassword => 'Use password';

  @override
  String validationFieldRequired(String label) {
    return '$label is required';
  }

  @override
  String validationTooLong(String label, int max) {
    return '$label must be $max characters or fewer';
  }

  @override
  String get validationNameTooLong => 'Name must be 40 characters or fewer';

  @override
  String get validationDuplicateMember => 'That name is already in the list';

  @override
  String get validationEmailInvalid => 'Enter a valid email address';

  @override
  String get validationPasswordShort =>
      'Password must be at least 6 characters';

  @override
  String get validationPasswordLong =>
      'Password must be 64 characters or fewer';

  @override
  String get validationInviteFormat => 'Invite codes are 6 characters long';

  @override
  String get recordSettlement => 'Record settlement';

  @override
  String get pays => 'pays';

  @override
  String get receives => 'receives';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get confirmPayment => 'Confirm payment';

  @override
  String get settlementRecorded => 'Settlement recorded';

  @override
  String get toBeSettled => 'To be settled';

  @override
  String get whoOwesWhom => 'Who owes whom';

  @override
  String get settleHint =>
      'Record a payment once it’s made. Balances update automatically.';

  @override
  String get settlementHistory => 'Settlement history';

  @override
  String get allSettled => 'All settled up!';

  @override
  String get allSettledMessage =>
      'Everyone in this cycle is even. Nice teamwork.';

  @override
  String get settleAction => 'Settle';

  @override
  String get profile => 'Profile';

  @override
  String get displayName => 'Display name';

  @override
  String get displayNameHint =>
      'This name is shared with your household members.';

  @override
  String get enterNameError => 'Enter your name';

  @override
  String get household => 'Household';

  @override
  String get householdAndMembers => 'Household & members';

  @override
  String get categories => 'Categories';

  @override
  String get defaultCategories => 'Default categories';

  @override
  String get customCategories => 'Custom categories';

  @override
  String get newCategory => 'New category';

  @override
  String get categoryName => 'Category name';

  @override
  String get categoryNameHint => 'e.g. Kids, Pets, Gym';

  @override
  String get icon => 'Icon';

  @override
  String get colour => 'Colour';

  @override
  String get addCategory => 'Add category';

  @override
  String get enterCategoryNameError => 'Enter a category name';

  @override
  String get categoryTooLongError => 'Keep it under 24 characters';

  @override
  String get duplicateCategoryError => 'That category already exists';

  @override
  String get inviteCodeCopied => 'Invite code copied';

  @override
  String get shareInviteHint =>
      'Share this code so friends and roommates can join your household.';

  @override
  String get members => 'Members';

  @override
  String get addMemberFieldHint => 'Name';

  @override
  String get addMemberHelper =>
      'Members you add will appear in expense splits automatically.';

  @override
  String get removeMemberMessage =>
      'Their past expenses stay in the history, but they will no longer see this household.';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleMember => 'Member';

  @override
  String get statusActive => 'Active';

  @override
  String get statusReady => 'Ready to settle';

  @override
  String get statusSettled => 'Settled';

  @override
  String get statusClosed => 'Closed';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusPartiallyPaid => 'Partially paid';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get spendingCycle => 'Spending cycle';

  @override
  String get currentCycle => 'Current cycle';

  @override
  String get noActiveCycle => 'No active cycle';

  @override
  String get ownersCanManage => 'Owners can manage cycles';

  @override
  String get closeCurrentCycle => 'Close current cycle';

  @override
  String get startNewCycle => 'Start a new cycle';

  @override
  String get closeCycle => 'Close cycle';

  @override
  String get closeCycleMessage =>
      'The cycle becomes read-only and historical. A new cycle will start next month.';

  @override
  String get data => 'Data';

  @override
  String get export => 'Export';

  @override
  String get csvOfCurrentCycle => 'CSV of the current cycle';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsSubtitle => 'Expenses, balances & reminders';

  @override
  String get notificationsSheet =>
      'Push notifications arrive with Firebase Cloud Messaging in the connected build.';

  @override
  String get appearance => 'Appearance';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get onValue => 'On';

  @override
  String get offValue => 'Off';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutSubtitle => 'Switch account or household';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutMessage => 'You can sign back in at any time.';

  @override
  String get appName => 'Hissa · Household Expense Tracker';

  @override
  String get version => 'v1.0.0';

  @override
  String get newCycleStarted => 'New cycle started';

  @override
  String get cycleClosed => 'Cycle closed';

  @override
  String get settleBeforeClose =>
      'Settle all balances before closing the cycle';

  @override
  String get csvExport => 'CSV export';

  @override
  String get currentCycleFallback => 'Current cycle';

  @override
  String get preview => 'Preview';

  @override
  String get copyCsv => 'Copy CSV to clipboard';

  @override
  String get csvCopied => 'CSV copied to clipboard';

  @override
  String get shareReport => 'Share report';

  @override
  String get csvCopiedShare => 'CSV copied - paste it anywhere to share';

  @override
  String get emptyPreview => '…';

  @override
  String get noExpensesForExport => 'No expenses to export yet';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'App display language';

  @override
  String get english => 'English';

  @override
  String get nepali => 'Nepali';

  @override
  String get expenseAmountError => 'Enter an amount greater than 0.';

  @override
  String get expenseDescriptionError => 'Add a short description.';

  @override
  String get expensePayerError => 'Choose who paid.';

  @override
  String get expenseParticipantError => 'Select at least one participant.';

  @override
  String get expensePercentError => 'Percentages must add up to 100%.';

  @override
  String get expenseCustomError => 'Custom amounts must add up to the total.';

  @override
  String get expenseSharesError => 'Enter at least one share unit.';
}
