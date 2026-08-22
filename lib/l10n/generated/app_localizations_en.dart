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
  String get loadingSpace => 'Switching space…';

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
    return '$name added to the space';
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
  String spaceMembersCount(int count) {
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
  String get selectGroupMembers => 'Select Members';

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
  String get spaceBalances => 'Space balances';

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
  String get allCategories => 'All categories';

  @override
  String get lifetimeSpending => 'Lifetime spending';

  @override
  String get filteredSpending => 'Filtered spending';

  @override
  String get thisWeek => 'This week';

  @override
  String get vsLastWeek => 'vs last week';

  @override
  String get vsLastMonth => 'vs last month';

  @override
  String get vsLastYear => 'vs last year';

  @override
  String get vsPreviousPeriod => 'vs previous period';

  @override
  String get dateRange => 'Select date range';

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
  String get legacyExpenseHint =>
      'This is a read-only historical record. It was created before ownership was tracked, so it can no longer be edited or deleted.';

  @override
  String get deleteExpenseTitle => 'Delete this expense?';

  @override
  String get deleteExpenseMessage =>
      'Deleting an expense changes the current space balances for everyone.';

  @override
  String get monthlySpending => 'Monthly spending';

  @override
  String get categoryBreakdown => 'Category breakdown';

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
  String get topCategories => 'Top categories';

  @override
  String get monthCompare => 'This month vs last month';

  @override
  String get totalSpent => 'Total spent';

  @override
  String get average => 'Average';

  @override
  String get spendingOverview => 'Spending overview';

  @override
  String get thisMonthTotal => 'This month';

  @override
  String get thisYearTotal => 'This year';

  @override
  String get allTimeTotal => 'All time';

  @override
  String get granularityDay => 'Day';

  @override
  String get granularityWeek => 'Week';

  @override
  String get granularityMonth => 'Month';

  @override
  String get granularityYear => 'Year';

  @override
  String get periodMonthly => 'Monthly';

  @override
  String get periodYearly => 'Yearly';

  @override
  String get periodLifetime => 'Lifetime';

  @override
  String get periodDaily => 'Daily';

  @override
  String get periodWeekly => 'Weekly';

  @override
  String get lastDays => 'the last 7 days';

  @override
  String get lastWeeks => 'the last 6 weeks';

  @override
  String get lastMonths => 'the last 6 months';

  @override
  String get lastYears => 'the last 5 years';

  @override
  String get chartSpent => 'Spent';

  @override
  String get chartPlanned => 'Planned';

  @override
  String get noSpendingChartTitle => 'Nothing to chart yet';

  @override
  String get noSpendingChartMessage =>
      'Add expenses to see your spending over time.';

  @override
  String get showingRecentWindow => 'Showing the most recent period';

  @override
  String spentInPeriod(String amount, String period) {
    return '$amount in $period';
  }

  @override
  String get addEstimate => 'Add estimate';

  @override
  String get estimatedExpenses => 'Estimated expenses';

  @override
  String get estimatedExpense => 'Estimate';

  @override
  String get estimateSectionSubtitle =>
      'Planned amounts for the month — not actual spending.';

  @override
  String get noEstimatesYet => 'No estimates yet';

  @override
  String get noEstimatesMessage =>
      'Add a planned amount to see how it compares with your actual spending.';

  @override
  String get editEstimate => 'Edit estimate';

  @override
  String get removeEstimate => 'Remove estimate';

  @override
  String get removeEstimateTitle => 'Remove this estimate?';

  @override
  String get removeEstimateMessage =>
      'The planned amount will be removed. No actual expenses are affected.';

  @override
  String estimateForMonth(String month) {
    return 'Estimate for $month';
  }

  @override
  String get estimateDescriptionHint => 'What are you planning for?';

  @override
  String get estimatedAmount => 'Estimated spending amount';

  @override
  String get saveEstimate => 'Save estimate';

  @override
  String get updateEstimate => 'Update estimate';

  @override
  String get estimateAmountError => 'Enter a planned amount greater than 0.';

  @override
  String get estimateSaveError =>
      'Couldn\'t save the estimate. Please try again.';

  @override
  String get spentSoFar => 'Spent so far';

  @override
  String get estimatedTotalShort => 'Estimated';

  @override
  String get remainingFromEstimate => 'Remaining';

  @override
  String overEstimateBy(String amount) {
    return 'Over by $amount';
  }

  @override
  String spentOfEstimate(String spent, String estimate) {
    return '$spent of $estimate estimated';
  }

  @override
  String get introTitle1 => 'Welcome to Hissa';

  @override
  String get introSubtitle1 =>
      'The simplest way for groups, roommates and families to track shared expenses together.';

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
      'Pick the setup that matches your group. You can change it anytime.';

  @override
  String get modeTwoPeople => 'Two People';

  @override
  String get modeTwoPeopleSubtitle => 'A couple or duo sharing life and bills';

  @override
  String get modeFamily => 'Family';

  @override
  String get modeFamilySubtitle => 'Parents, kids and the whole family';

  @override
  String get modeRoommates => 'Roommates';

  @override
  String get modeRoommatesSubtitle => 'Flatmates splitting rent and utilities';

  @override
  String get modeOther => 'Other';

  @override
  String get modeOtherSubtitle => 'Any small group sharing expenses';

  @override
  String get setUpSubtitle => 'Enter an invite code to join a space';

  @override
  String get create => 'Create';

  @override
  String get join => 'Join';

  @override
  String get whoLivesHere => 'Who lives here?';

  @override
  String get addMember => 'Add Member';

  @override
  String get name => 'Name';

  @override
  String get currency => 'Currency';

  @override
  String get inviteLater =>
      'You can invite more people later from Space → Members';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get inviteCodeHint => 'ABCDE2';

  @override
  String get inviteCodeHelp =>
      'Ask the space owner for their invite code. Codes are shown in Settings → Space.';

  @override
  String get inviteNotFound =>
      'Invite code not found. Check the code and try again.';

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
  String get yourSpaces => 'Spaces you own';

  @override
  String get joinedSpaces => 'Spaces you\'ve joined';

  @override
  String get noSpacesYet => 'No spaces yet';

  @override
  String get noSpace => 'No space';

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
  String welcomeUser(String name) {
    return 'Welcome, $name';
  }

  @override
  String get authSignupSubtitle => 'Start tracking shared expenses in seconds.';

  @override
  String get authLoginSubtitle => 'Log in to keep your spaces in sync.';

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
      'You pay, then request settlement. The member you owe approves it before the balance updates.';

  @override
  String get settlementHistory => 'Settlement history';

  @override
  String get allSettled => 'All settled up!';

  @override
  String get allSettledMessage =>
      'Everyone in this cycle is even. Nice teamwork.';

  @override
  String get nothingToSettleTitle => 'Nothing to settle yet';

  @override
  String get noSettlementsMessage =>
      'No expenses have been recorded in this cycle yet. Add your first expense and the who-owes-whom breakdown will appear here.';

  @override
  String get settleAction => 'Settle';

  @override
  String get requestSettlementTitle => 'Request settlement';

  @override
  String get requestSettlementAction => 'Send request';

  @override
  String creditorApprovalNote(String name) {
    return '$name must approve this request before the amount is marked as settled.';
  }

  @override
  String maxOutstanding(String amount) {
    return 'Up to $amount';
  }

  @override
  String get pendingRequestsSection => 'Pending approvals';

  @override
  String waitingApprovalFrom(String name) {
    return 'Waiting for $name to approve';
  }

  @override
  String awaitingDebtorRequest(String name) {
    return '$name owes you — waiting for their settlement request';
  }

  @override
  String get statusApproved => 'Approved · Settled';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get requestAgain => 'Request again';

  @override
  String settlementRequestedToast(String name) {
    return 'Settlement request sent to $name';
  }

  @override
  String get settlementApprovedToast => 'Settlement approved and recorded';

  @override
  String get settlementRejectedToast =>
      'Request rejected. You can send a new one.';

  @override
  String get amountExceedsOutstanding =>
      'The amount cannot exceed what you still owe.';

  @override
  String get profile => 'Profile';

  @override
  String get displayName => 'Display name';

  @override
  String get displayNameHint => 'This name is shared with your space members.';

  @override
  String get enterNameError => 'Enter your name';

  @override
  String get space => 'Space';

  @override
  String get spaceAndMembers => 'Space & members';

  @override
  String get categories => 'Categories';

  @override
  String get memberGroups => 'Member Groups';

  @override
  String get memberGroupsSubtitle =>
      'Create groups to split as a single participant';

  @override
  String get noMemberGroups => 'No member groups yet';

  @override
  String get noMemberGroupsDescription =>
      'Create a group to combine members into a single participant when splitting expenses.';

  @override
  String get onlyOwnerCanCreateGroups =>
      'Only the space owner can create member groups.';

  @override
  String get requestGroup => 'Request a group';

  @override
  String get requestGroupDescription =>
      'Ask the space owner to create a group containing you and the members you choose. Only the owner can create groups.';

  @override
  String get requestGroupTitle => 'Request Member Group';

  @override
  String get requestGroupMembersHint =>
      'Choose members to group with you. The group will be owned by you.';

  @override
  String get groupRequested => 'Group request sent to the owner';

  @override
  String get groupRequestFailed => 'Failed to send group request';

  @override
  String get groupRequestAlreadyPending =>
      'You already have a pending group request.';

  @override
  String get noMembersToRequest =>
      'No other members are available to group with';

  @override
  String get requestGroupUnavailable =>
      'Member groups need at least three members in this space.';

  @override
  String get pendingGroupRequests => 'Pending group requests';

  @override
  String get pendingGroupRequestsDescription =>
      'Members have asked you to create a group for them. Approving creates the group owned by the requester.';

  @override
  String get pendingApproval => 'Pending approval';

  @override
  String get pendingApprovalSection => 'Waiting for approval';

  @override
  String get openByDefault => 'Open by default next time';

  @override
  String defaultSpaceSetMessage(String space) {
    return '$space will open by default next time';
  }

  @override
  String get defaultSpaceRemovedMessage => 'No longer the default space';

  @override
  String get deleteSpace => 'Delete';

  @override
  String get leaveSpace => 'Leave';

  @override
  String get leaveBlockedOutstanding =>
      'You have an outstanding balance. Settle your dues before leaving the space.';

  @override
  String deletingSpaceIn(String space, int seconds) {
    return 'Deleting $space in ${seconds}s';
  }

  @override
  String leavingSpaceIn(String space, int seconds) {
    return 'Leaving $space in ${seconds}s';
  }

  @override
  String get undo => 'Undo';

  @override
  String get spaceActionCancelled => 'Action cancelled. Nothing changed.';

  @override
  String get spaceDeleted => 'Space deleted.';

  @override
  String get spaceLeft => 'You left the space.';

  @override
  String get yourGroupRequestPending =>
      'Your group request is pending approval. You\'ll be notified once the space owner decides.';

  @override
  String get noPendingGroupRequests => 'No pending group requests';

  @override
  String get requestedBy => 'Requested by';

  @override
  String get groupRequestApproved => 'Group created';

  @override
  String get groupRequestApprovedFail => 'Failed to approve request';

  @override
  String get groupRequestRejected => 'Request rejected';

  @override
  String get groupRequestRejectFail => 'Failed to reject request';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get groupCreationUnavailable =>
      'Member groups need at least three members in this space.';

  @override
  String get alreadyInGroup => 'You already belong to a member group.';

  @override
  String get createMemberGroup => 'Create Member Group';

  @override
  String get createGroupDescription =>
      'Select members to add to this group. The group will be owned by you.';

  @override
  String get groupOwner => 'Owner';

  @override
  String get youAreOwner => 'You are the owner of this group';

  @override
  String get noOtherMembersToAdd => 'No other space members to add';

  @override
  String get managedByYou => 'Managed by you';

  @override
  String get managedBy => 'Managed by';

  @override
  String get groupCreated => 'Group created';

  @override
  String get groupCreateFailed => 'Failed to create group';

  @override
  String get deleteGroupTitle => 'Delete Group';

  @override
  String get deleteGroupMessage =>
      'This group will be removed. Historical expenses using this group will not be affected.';

  @override
  String get deleteGroup => 'Delete';

  @override
  String get groupDeleted => 'Group deleted';

  @override
  String get groupDeleteFailed => 'Failed to delete group';

  @override
  String get addGroupMember => 'Add Member';

  @override
  String get memberAdded => 'Member added';

  @override
  String get memberAddFailed => 'Failed to add member';

  @override
  String get removeMember => 'Remove';

  @override
  String get memberRemoved => 'Member removed';

  @override
  String get memberRemoveFailed => 'Failed to remove member';

  @override
  String removeGroupMemberTitle(Object name) {
    return 'Remove $name from this group?';
  }

  @override
  String get removeGroupMemberMessage =>
      'They will no longer be part of this group. Historical expenses are not affected.';

  @override
  String get groupCountsAsOneParticipant =>
      'This group counts as one participant.';

  @override
  String get noMembersAvailableToAdd => 'No members available to add';

  @override
  String get groupFull =>
      'This group has reached its maximum size. Remove a member before adding another.';

  @override
  String get groupMembers => 'Members';

  @override
  String get noMembersInGroup => 'No members in this group yet';

  @override
  String get groupOwnerLabel => 'Group Owner';

  @override
  String get members => 'Members';

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
      'Share this code so friends and roommates can join your space.';

  @override
  String get inviteMember => 'Invite a member';

  @override
  String get inviteMemberHint => 'person@example.com';

  @override
  String get inviteMemberHelper =>
      'An invitation email is sent to the address. Invited members appear in expense splits.';

  @override
  String invitedMember(String email) {
    return '$email invited to the space';
  }

  @override
  String get inviteMemberAlreadyMember =>
      'That email already belongs to a member of this space';

  @override
  String get duplicateEmailError => 'That email is already in the list';

  @override
  String get pendingJoinRequests => 'Pending join requests';

  @override
  String get pendingJoinRequestsDescription =>
      'Members have asked to join this space. Approving adds them to the space.';

  @override
  String get joinRequestPendingDescription =>
      'Your request to join this space is pending approval. You\'ll be able to enter the space once the owner approves it.';

  @override
  String get joinRequestApproved => 'Join request approved';

  @override
  String get joinRequestApprovedFail => 'Failed to approve request';

  @override
  String get joinRequestRejected => 'Join request rejected';

  @override
  String get joinRequestRejectFail => 'Failed to reject request';

  @override
  String get wantsToJoinSpace => 'wants to join this space';

  @override
  String get addMemberFieldHint => 'Name';

  @override
  String get addMemberHelper =>
      'Members you add will appear in expense splits automatically.';

  @override
  String get removeMemberMessage =>
      'Their past expenses stay in the history, but they will no longer see this space.';

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
      'The cycle becomes read-only and historical. A new cycle can be started afterwards.';

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
      'In-app notifications keep you up to date without needing push.';

  @override
  String get notificationExpenseAdded => 'An expense was added';

  @override
  String get notificationExpenseUpdated => 'An expense was updated';

  @override
  String get notificationSettlementRecorded => 'A settlement was recorded';

  @override
  String get notificationSettlementRequested =>
      'A settlement request awaits your approval';

  @override
  String get notificationSettlementApproved =>
      'Your settlement request was approved';

  @override
  String get notificationSettlementRejected =>
      'Your settlement request was declined';

  @override
  String get notificationSpaceInvited => 'You were invited to a Space';

  @override
  String get notificationSpaceJoinRequested =>
      'A new join request awaits your approval';

  @override
  String get notificationSpaceJoinApproved => 'Your join request was approved';

  @override
  String get notificationSpaceJoinRejected => 'Your join request was declined';

  @override
  String get notificationGroupRequested =>
      'A new group request awaits your approval';

  @override
  String get notificationGroupApproved => 'Your group request was approved';

  @override
  String get notificationGroupRejected => 'Your group request was declined';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get noNotificationsMessage =>
      'Activity in your Spaces and requests will show up here.';

  @override
  String get inSpace => 'in a Space';

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
  String get signOutSubtitle => 'Switch account or space';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutMessage => 'You can sign back in at any time.';

  @override
  String get appName => 'Hissa · Space Expense Tracker';

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

  @override
  String get chooseCycleType => 'Spending cycle';

  @override
  String get monthlyCycle => 'Monthly';

  @override
  String get monthlyCycleDescription =>
      'Tracks the running month automatically';

  @override
  String get customCycle => 'Custom';

  @override
  String get customCycleDescription => 'An open-ended cycle you manage';

  @override
  String get renameCycle => 'Rename cycle';

  @override
  String get renameCycleTitle => 'Rename cycle';

  @override
  String get cycleName => 'Cycle name';

  @override
  String get done => 'Done';

  @override
  String get cycleRenamed => 'Cycle renamed';

  @override
  String get previousCycles => 'Previous cycles';

  @override
  String previousCyclesCount(int count) {
    return '$count closed cycles';
  }

  @override
  String get cycleDetails => 'Cycle details';

  @override
  String get spentLabel => 'spent';

  @override
  String get expensesCount => 'Expenses';

  @override
  String get noExpensesInCycle => 'No expenses recorded in this cycle.';

  @override
  String get noPreviousCycles => 'No previous cycles yet.';

  @override
  String get cycleStatusActive => 'Active';

  @override
  String get cycleStatusReadyToSettle => 'Ready to settle';

  @override
  String get cycleStatusSettled => 'Settled';

  @override
  String get cycleStatusClosed => 'Closed';
}
