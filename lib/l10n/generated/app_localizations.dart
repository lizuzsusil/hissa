import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ne.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ne'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Hissa'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'All your expenses, in one place'**
  String get tagline;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @settle.
  ///
  /// In en, this message translates to:
  /// **'Settle'**
  String get settle;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @loadingSpace.
  ///
  /// In en, this message translates to:
  /// **'Switching space…'**
  String get loadingSpace;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @cycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get cycle;

  /// No description provided for @even.
  ///
  /// In en, this message translates to:
  /// **'Even'**
  String get even;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @attached.
  ///
  /// In en, this message translates to:
  /// **'Attached'**
  String get attached;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// Count of pending settlement proposals
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 settlement waiting} other{{count} settlements waiting}}'**
  String settlementsWaiting(int count);

  /// Number of people in a split
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String splitPersons(int count);

  /// Export header summary, e.g. '3 expenses · Rs. 1,000'
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expense · {total}} other{{count} expenses · {total}}}'**
  String expensesAndTotal(int count, String total);

  /// No description provided for @memberPaidShare.
  ///
  /// In en, this message translates to:
  /// **'Paid {paid} · Share {share}'**
  String memberPaidShare(String paid, String share);

  /// No description provided for @paidByMemberDay.
  ///
  /// In en, this message translates to:
  /// **'{name} paid · {day}'**
  String paidByMemberDay(String name, String day);

  /// No description provided for @owes.
  ///
  /// In en, this message translates to:
  /// **'{from} owes {to}'**
  String owes(String from, String to);

  /// No description provided for @fromTo.
  ///
  /// In en, this message translates to:
  /// **'{from} → {to}'**
  String fromTo(String from, String to);

  /// No description provided for @settlementMethodDay.
  ///
  /// In en, this message translates to:
  /// **'{method} · {day}'**
  String settlementMethodDay(String method, String day);

  /// No description provided for @memberJoinedDate.
  ///
  /// In en, this message translates to:
  /// **'{role} · Joined {date}'**
  String memberJoinedDate(String role, String date);

  /// No description provided for @cycleNameByCategory.
  ///
  /// In en, this message translates to:
  /// **'{name} by category'**
  String cycleNameByCategory(String name);

  /// No description provided for @addedMember.
  ///
  /// In en, this message translates to:
  /// **'{name} added to the space'**
  String addedMember(String name);

  /// No description provided for @removeMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeMemberTitle(String name);

  /// No description provided for @closeCycleTitle.
  ///
  /// In en, this message translates to:
  /// **'Close {name}?'**
  String closeCycleTitle(String name);

  /// No description provided for @spaceMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String spaceMembersCount(int count);

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What was this for?'**
  String get descriptionHint;

  /// No description provided for @paidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get paidBy;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @splitBetween.
  ///
  /// In en, this message translates to:
  /// **'Split between'**
  String get splitBetween;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @noteOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get noteOptionalHint;

  /// No description provided for @splitPreview.
  ///
  /// In en, this message translates to:
  /// **'Split preview'**
  String get splitPreview;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @selectParticipant.
  ///
  /// In en, this message translates to:
  /// **'Select at least one participant.'**
  String get selectParticipant;

  /// No description provided for @splitLabelEqual.
  ///
  /// In en, this message translates to:
  /// **'Equal'**
  String get splitLabelEqual;

  /// No description provided for @splitLabelPercent.
  ///
  /// In en, this message translates to:
  /// **'Percent'**
  String get splitLabelPercent;

  /// No description provided for @splitLabelAmounts.
  ///
  /// In en, this message translates to:
  /// **'Amounts'**
  String get splitLabelAmounts;

  /// No description provided for @splitLabelShares.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get splitLabelShares;

  /// No description provided for @assigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assigned;

  /// No description provided for @totalShares.
  ///
  /// In en, this message translates to:
  /// **'Total shares'**
  String get totalShares;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroup;

  /// No description provided for @ungroup.
  ///
  /// In en, this message translates to:
  /// **'Remove group'**
  String get ungroup;

  /// No description provided for @selectGroupMembers.
  ///
  /// In en, this message translates to:
  /// **'Select Members'**
  String get selectGroupMembers;

  /// No description provided for @editExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get editExpense;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpense;

  /// No description provided for @yourBalance.
  ///
  /// In en, this message translates to:
  /// **'Your balance'**
  String get yourBalance;

  /// No description provided for @youPaid.
  ///
  /// In en, this message translates to:
  /// **'You paid'**
  String get youPaid;

  /// No description provided for @yourShare.
  ///
  /// In en, this message translates to:
  /// **'Your share'**
  String get yourShare;

  /// No description provided for @youReceive.
  ///
  /// In en, this message translates to:
  /// **'You receive'**
  String get youReceive;

  /// No description provided for @youOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get youOwe;

  /// No description provided for @totalSpending.
  ///
  /// In en, this message translates to:
  /// **'Total spending'**
  String get totalSpending;

  /// No description provided for @spaceBalances.
  ///
  /// In en, this message translates to:
  /// **'Space balances'**
  String get spaceBalances;

  /// No description provided for @recentExpenses.
  ///
  /// In en, this message translates to:
  /// **'Recent expenses'**
  String get recentExpenses;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get lastMonth;

  /// No description provided for @vsMonth.
  ///
  /// In en, this message translates to:
  /// **'vs {month}'**
  String vsMonth(Object month);

  /// No description provided for @noExpensesYet.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get noExpensesYet;

  /// No description provided for @noExpensesMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to add your first shared expense.'**
  String get noExpensesMessage;

  /// No description provided for @settleUp.
  ///
  /// In en, this message translates to:
  /// **'Settle up'**
  String get settleUp;

  /// No description provided for @searchExpenses.
  ///
  /// In en, this message translates to:
  /// **'Search expenses'**
  String get searchExpenses;

  /// No description provided for @filterExpenses.
  ///
  /// In en, this message translates to:
  /// **'Filter expenses'**
  String get filterExpenses;

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// No description provided for @noMatchingExpenses.
  ///
  /// In en, this message translates to:
  /// **'No matching expenses'**
  String get noMatchingExpenses;

  /// No description provided for @noMatchingMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter, or add a new expense.'**
  String get noMatchingMessage;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategories;

  /// No description provided for @lifetimeSpending.
  ///
  /// In en, this message translates to:
  /// **'Lifetime spending'**
  String get lifetimeSpending;

  /// No description provided for @filteredSpending.
  ///
  /// In en, this message translates to:
  /// **'Filtered spending'**
  String get filteredSpending;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @vsLastWeek.
  ///
  /// In en, this message translates to:
  /// **'vs last week'**
  String get vsLastWeek;

  /// No description provided for @vsLastMonth.
  ///
  /// In en, this message translates to:
  /// **'vs last month'**
  String get vsLastMonth;

  /// No description provided for @vsLastYear.
  ///
  /// In en, this message translates to:
  /// **'vs last year'**
  String get vsLastYear;

  /// No description provided for @vsPreviousPeriod.
  ///
  /// In en, this message translates to:
  /// **'vs previous period'**
  String get vsPreviousPeriod;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Select date range'**
  String get dateRange;

  /// No description provided for @expenseDetails.
  ///
  /// In en, this message translates to:
  /// **'Expense details'**
  String get expenseDetails;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get split;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// No description provided for @whoPaysWhat.
  ///
  /// In en, this message translates to:
  /// **'Who pays what'**
  String get whoPaysWhat;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @cycleClosedHint.
  ///
  /// In en, this message translates to:
  /// **'This cycle is closed, so expenses can no longer be edited.'**
  String get cycleClosedHint;

  /// No description provided for @legacyExpenseHint.
  ///
  /// In en, this message translates to:
  /// **'This is a read-only historical record. It was created before ownership was tracked, so it can no longer be edited or deleted.'**
  String get legacyExpenseHint;

  /// No description provided for @deleteExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this expense?'**
  String get deleteExpenseTitle;

  /// No description provided for @deleteExpenseMessage.
  ///
  /// In en, this message translates to:
  /// **'Deleting an expense changes the current space balances for everyone.'**
  String get deleteExpenseMessage;

  /// No description provided for @monthlySpending.
  ///
  /// In en, this message translates to:
  /// **'Monthly spending'**
  String get monthlySpending;

  /// No description provided for @categoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category breakdown'**
  String get categoryBreakdown;

  /// No description provided for @whoPaidThisCycle.
  ///
  /// In en, this message translates to:
  /// **'Who paid this cycle'**
  String get whoPaidThisCycle;

  /// No description provided for @selectCycle.
  ///
  /// In en, this message translates to:
  /// **'Select cycle'**
  String get selectCycle;

  /// No description provided for @nothingToChart.
  ///
  /// In en, this message translates to:
  /// **'Nothing to chart yet'**
  String get nothingToChart;

  /// No description provided for @nothingToChartMessage.
  ///
  /// In en, this message translates to:
  /// **'Add expenses to see your spending breakdown.'**
  String get nothingToChartMessage;

  /// No description provided for @lifetimeSummary.
  ///
  /// In en, this message translates to:
  /// **'Lifetime summary'**
  String get lifetimeSummary;

  /// No description provided for @topCategories.
  ///
  /// In en, this message translates to:
  /// **'Top categories'**
  String get topCategories;

  /// No description provided for @monthCompare.
  ///
  /// In en, this message translates to:
  /// **'This month vs last month'**
  String get monthCompare;

  /// No description provided for @totalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get totalSpent;

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided for @spendingOverview.
  ///
  /// In en, this message translates to:
  /// **'Spending overview'**
  String get spendingOverview;

  /// No description provided for @thisMonthTotal.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonthTotal;

  /// No description provided for @thisYearTotal.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get thisYearTotal;

  /// No description provided for @allTimeTotal.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTimeTotal;

  /// No description provided for @granularityDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get granularityDay;

  /// No description provided for @granularityWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get granularityWeek;

  /// No description provided for @granularityMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get granularityMonth;

  /// No description provided for @granularityYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get granularityYear;

  /// No description provided for @periodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get periodMonthly;

  /// No description provided for @periodYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get periodYearly;

  /// No description provided for @periodLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get periodLifetime;

  /// No description provided for @periodDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get periodDaily;

  /// No description provided for @periodWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get periodWeekly;

  /// No description provided for @lastDays.
  ///
  /// In en, this message translates to:
  /// **'the last 7 days'**
  String get lastDays;

  /// No description provided for @lastWeeks.
  ///
  /// In en, this message translates to:
  /// **'the last 6 weeks'**
  String get lastWeeks;

  /// No description provided for @lastMonths.
  ///
  /// In en, this message translates to:
  /// **'the last 6 months'**
  String get lastMonths;

  /// No description provided for @lastYears.
  ///
  /// In en, this message translates to:
  /// **'the last 5 years'**
  String get lastYears;

  /// No description provided for @chartSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get chartSpent;

  /// No description provided for @chartPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get chartPlanned;

  /// No description provided for @noSpendingChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to chart yet'**
  String get noSpendingChartTitle;

  /// No description provided for @noSpendingChartMessage.
  ///
  /// In en, this message translates to:
  /// **'Add expenses to see your spending over time.'**
  String get noSpendingChartMessage;

  /// No description provided for @showingRecentWindow.
  ///
  /// In en, this message translates to:
  /// **'Showing the most recent period'**
  String get showingRecentWindow;

  /// Header line inside the spending chart, e.g. 'Rs. 12,000 in Monthly'
  ///
  /// In en, this message translates to:
  /// **'{amount} in {period}'**
  String spentInPeriod(String amount, String period);

  /// No description provided for @addEstimate.
  ///
  /// In en, this message translates to:
  /// **'Add estimate'**
  String get addEstimate;

  /// No description provided for @estimatedExpenses.
  ///
  /// In en, this message translates to:
  /// **'Estimated expenses'**
  String get estimatedExpenses;

  /// No description provided for @estimatedExpense.
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get estimatedExpense;

  /// No description provided for @estimateSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Planned amounts for the month — not actual spending.'**
  String get estimateSectionSubtitle;

  /// No description provided for @noEstimatesYet.
  ///
  /// In en, this message translates to:
  /// **'No estimates yet'**
  String get noEstimatesYet;

  /// No description provided for @noEstimatesMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a planned amount to see how it compares with your actual spending.'**
  String get noEstimatesMessage;

  /// No description provided for @editEstimate.
  ///
  /// In en, this message translates to:
  /// **'Edit estimate'**
  String get editEstimate;

  /// No description provided for @removeEstimate.
  ///
  /// In en, this message translates to:
  /// **'Remove estimate'**
  String get removeEstimate;

  /// No description provided for @removeEstimateTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this estimate?'**
  String get removeEstimateTitle;

  /// No description provided for @removeEstimateMessage.
  ///
  /// In en, this message translates to:
  /// **'The planned amount will be removed. No actual expenses are affected.'**
  String get removeEstimateMessage;

  /// Title of the estimate form, e.g. 'Estimate for July 2026'
  ///
  /// In en, this message translates to:
  /// **'Estimate for {month}'**
  String estimateForMonth(String month);

  /// No description provided for @estimateDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What are you planning for?'**
  String get estimateDescriptionHint;

  /// No description provided for @estimatedAmount.
  ///
  /// In en, this message translates to:
  /// **'Estimated spending amount'**
  String get estimatedAmount;

  /// No description provided for @saveEstimate.
  ///
  /// In en, this message translates to:
  /// **'Save estimate'**
  String get saveEstimate;

  /// No description provided for @updateEstimate.
  ///
  /// In en, this message translates to:
  /// **'Update estimate'**
  String get updateEstimate;

  /// No description provided for @estimateAmountError.
  ///
  /// In en, this message translates to:
  /// **'Enter a planned amount greater than 0.'**
  String get estimateAmountError;

  /// No description provided for @estimateSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the estimate. Please try again.'**
  String get estimateSaveError;

  /// No description provided for @spentSoFar.
  ///
  /// In en, this message translates to:
  /// **'Spent so far'**
  String get spentSoFar;

  /// No description provided for @estimatedTotalShort.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get estimatedTotalShort;

  /// No description provided for @remainingFromEstimate.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remainingFromEstimate;

  /// No description provided for @overEstimateBy.
  ///
  /// In en, this message translates to:
  /// **'Over by {amount}'**
  String overEstimateBy(String amount);

  /// Progress line, e.g. 'Rs. 8,000 of Rs. 12,000 estimated'
  ///
  /// In en, this message translates to:
  /// **'{spent} of {estimate} estimated'**
  String spentOfEstimate(String spent, String estimate);

  /// No description provided for @introTitle1.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Hissa'**
  String get introTitle1;

  /// No description provided for @introSubtitle1.
  ///
  /// In en, this message translates to:
  /// **'The simplest way for groups, roommates and families to track shared expenses together.'**
  String get introSubtitle1;

  /// No description provided for @introTitle2.
  ///
  /// In en, this message translates to:
  /// **'Track every expense'**
  String get introTitle2;

  /// No description provided for @introSubtitle2.
  ///
  /// In en, this message translates to:
  /// **'Add expenses in seconds. Split bills equally, by percentage or by custom amounts — Hissa keeps the math exact.'**
  String get introSubtitle2;

  /// No description provided for @introTitle3.
  ///
  /// In en, this message translates to:
  /// **'Settle up fairly'**
  String get introTitle3;

  /// No description provided for @introSubtitle3.
  ///
  /// In en, this message translates to:
  /// **'See who owes whom at a glance and record payments with cash, bank transfer, eSewa or Khalti in one tap.'**
  String get introSubtitle3;

  /// No description provided for @introTitle4.
  ///
  /// In en, this message translates to:
  /// **'Understand your spending'**
  String get introTitle4;

  /// No description provided for @introSubtitle4.
  ///
  /// In en, this message translates to:
  /// **'Monthly insights, category breakdowns and one-tap CSV export keep you on top of where the money goes.'**
  String get introSubtitle4;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'How are you\nsharing expenses?'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the setup that matches your group. You can change it anytime.'**
  String get onboardingSubtitle;

  /// No description provided for @modeTwoPeople.
  ///
  /// In en, this message translates to:
  /// **'Two People'**
  String get modeTwoPeople;

  /// No description provided for @modeTwoPeopleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A couple or duo sharing life and bills'**
  String get modeTwoPeopleSubtitle;

  /// No description provided for @modeFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get modeFamily;

  /// No description provided for @modeFamilySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Parents, kids and the whole family'**
  String get modeFamilySubtitle;

  /// No description provided for @modeRoommates.
  ///
  /// In en, this message translates to:
  /// **'Roommates'**
  String get modeRoommates;

  /// No description provided for @modeRoommatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Flatmates splitting rent and utilities'**
  String get modeRoommatesSubtitle;

  /// No description provided for @modeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get modeOther;

  /// No description provided for @modeOtherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Any small group sharing expenses'**
  String get modeOtherSubtitle;

  /// No description provided for @setUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter an invite code to join a space'**
  String get setUpSubtitle;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @whoLivesHere.
  ///
  /// In en, this message translates to:
  /// **'Who lives here?'**
  String get whoLivesHere;

  /// No description provided for @addMember.
  ///
  /// In en, this message translates to:
  /// **'Add Member'**
  String get addMember;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @inviteLater.
  ///
  /// In en, this message translates to:
  /// **'You can invite more people later from Space → Members'**
  String get inviteLater;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// No description provided for @inviteCodeHint.
  ///
  /// In en, this message translates to:
  /// **'ABCDE2'**
  String get inviteCodeHint;

  /// No description provided for @inviteCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Ask the space owner for their invite code. Codes are shown in Settings → Space.'**
  String get inviteCodeHelp;

  /// No description provided for @inviteNotFound.
  ///
  /// In en, this message translates to:
  /// **'Invite code not found. Check the code and try again.'**
  String get inviteNotFound;

  /// No description provided for @enterMemberNameError.
  ///
  /// In en, this message translates to:
  /// **'Enter a member name'**
  String get enterMemberNameError;

  /// No description provided for @duplicateMemberError.
  ///
  /// In en, this message translates to:
  /// **'That name is already in the list'**
  String get duplicateMemberError;

  /// No description provided for @enterInviteCodeError.
  ///
  /// In en, this message translates to:
  /// **'Enter the invite code'**
  String get enterInviteCodeError;

  /// No description provided for @inviteCodeFormatError.
  ///
  /// In en, this message translates to:
  /// **'Invite codes are 6 characters long'**
  String get inviteCodeFormatError;

  /// No description provided for @mySpaces.
  ///
  /// In en, this message translates to:
  /// **'My Spaces'**
  String get mySpaces;

  /// No description provided for @mySpacesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All your expense spaces in one place'**
  String get mySpacesSubtitle;

  /// No description provided for @yourSpaces.
  ///
  /// In en, this message translates to:
  /// **'Spaces you own'**
  String get yourSpaces;

  /// No description provided for @joinedSpaces.
  ///
  /// In en, this message translates to:
  /// **'Spaces you\'ve joined'**
  String get joinedSpaces;

  /// No description provided for @noSpacesYet.
  ///
  /// In en, this message translates to:
  /// **'No spaces yet'**
  String get noSpacesYet;

  /// No description provided for @noSpace.
  ///
  /// In en, this message translates to:
  /// **'No space'**
  String get noSpace;

  /// No description provided for @noSpacesMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a space to start tracking your expenses, or join an existing space.'**
  String get noSpacesMessage;

  /// No description provided for @createSpace.
  ///
  /// In en, this message translates to:
  /// **'Create Space'**
  String get createSpace;

  /// No description provided for @joinSpace.
  ///
  /// In en, this message translates to:
  /// **'Join Space'**
  String get joinSpace;

  /// No description provided for @switchSpace.
  ///
  /// In en, this message translates to:
  /// **'My Spaces'**
  String get switchSpace;

  /// No description provided for @switchSpaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch between your spaces'**
  String get switchSpaceSubtitle;

  /// No description provided for @splitMode.
  ///
  /// In en, this message translates to:
  /// **'Split Mode'**
  String get splitMode;

  /// No description provided for @personalMode.
  ///
  /// In en, this message translates to:
  /// **'Personal Mode'**
  String get personalMode;

  /// No description provided for @spaceName.
  ///
  /// In en, this message translates to:
  /// **'Space name'**
  String get spaceName;

  /// No description provided for @spaceNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Our Home'**
  String get spaceNameHint;

  /// No description provided for @spaceNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Space name is required'**
  String get spaceNameRequired;

  /// No description provided for @chooseSpaceMode.
  ///
  /// In en, this message translates to:
  /// **'Choose how you\'ll use it'**
  String get chooseSpaceMode;

  /// No description provided for @splitModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Share expenses, calculate balances and settle up.'**
  String get splitModeDescription;

  /// No description provided for @personalModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Track your own spending without splitting or settling.'**
  String get personalModeDescription;

  /// No description provided for @createSpaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a Space'**
  String get createSpaceTitle;

  /// No description provided for @createSpaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Name your space and pick how you\'ll use it.'**
  String get createSpaceSubtitle;

  /// No description provided for @createdSpaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Space created'**
  String get createdSpaceTitle;

  /// No description provided for @joinedSpaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Space joined'**
  String get joinedSpaceTitle;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createYourAccount;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Greeting shown in the dashboard header
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcomeUser(String name);

  /// No description provided for @authSignupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start tracking shared expenses in seconds.'**
  String get authSignupSubtitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to keep your spaces in sync.'**
  String get authLoginSubtitle;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @logInLink.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logInLink;

  /// No description provided for @newToHissa.
  ///
  /// In en, this message translates to:
  /// **'New to Hissa? '**
  String get newToHissa;

  /// No description provided for @createOne.
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get createOne;

  /// No description provided for @errEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email address is required'**
  String get errEmailRequired;

  /// No description provided for @errEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get errEmailInvalid;

  /// No description provided for @errPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get errPasswordRequired;

  /// No description provided for @errPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get errPasswordShort;

  /// No description provided for @errPasswordLong.
  ///
  /// In en, this message translates to:
  /// **'Password must be 64 characters or fewer'**
  String get errPasswordLong;

  /// No description provided for @errNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Your name is required'**
  String get errNameRequired;

  /// No description provided for @errFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get errFieldRequired;

  /// No description provided for @errTooLong.
  ///
  /// In en, this message translates to:
  /// **'Name must be 40 characters or fewer'**
  String get errTooLong;

  /// No description provided for @errIncorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password. Try again or create an account.'**
  String get errIncorrectCredentials;

  /// No description provided for @authGoogleConflict.
  ///
  /// In en, this message translates to:
  /// **'That email already has a password account. Log in with your email and password instead.'**
  String get authGoogleConflict;

  /// No description provided for @authEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for that email. Log in instead.'**
  String get authEmailInUse;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'That password is too weak. Use at least 6 characters.'**
  String get authWeakPassword;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'That email address does not look valid.'**
  String get authInvalidEmail;

  /// No description provided for @authIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authIncorrect;

  /// No description provided for @authUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get authUserDisabled;

  /// No description provided for @authTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait and try again.'**
  String get authTooManyRequests;

  /// No description provided for @authNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your connection and retry.'**
  String get authNetwork;

  /// No description provided for @authOperationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This sign-in method is not enabled yet. Enable it in the Firebase console.'**
  String get authOperationNotAllowed;

  /// No description provided for @authConfigError.
  ///
  /// In en, this message translates to:
  /// **'Authentication is not configured correctly. Check the Firebase console app config and keys.'**
  String get authConfigError;

  /// No description provided for @authFirestoreDenied.
  ///
  /// In en, this message translates to:
  /// **'The database is rejecting this action. Publish the firestore.rules file to Firebase.'**
  String get authFirestoreDenied;

  /// No description provided for @authFirestoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The database is busy or not ready yet. Please try again.'**
  String get authFirestoreUnavailable;

  /// No description provided for @authGoogleConfig.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not configured yet. Add your Android SHA-1 fingerprint in the Firebase console, then re-run `flutterfire configure`.'**
  String get authGoogleConfig;

  /// No description provided for @authGooglePlayServices.
  ///
  /// In en, this message translates to:
  /// **'Google Play services is unavailable or misconfigured on this device.'**
  String get authGooglePlayServices;

  /// No description provided for @authGoogleUi.
  ///
  /// In en, this message translates to:
  /// **'The Google sign-in window could not be shown right now. Please try again.'**
  String get authGoogleUi;

  /// No description provided for @authSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Check the debug logs for the exact error.'**
  String get authSomethingWentWrong;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @biometricLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in with biometrics'**
  String get biometricLogin;

  /// No description provided for @biometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is not available on this device.'**
  String get biometricUnavailable;

  /// No description provided for @biometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication failed. Please try again.'**
  String get biometricFailed;

  /// No description provided for @biometricNotEnrolled.
  ///
  /// In en, this message translates to:
  /// **'No biometrics enrolled. Set up Face ID / Touch ID in Settings.'**
  String get biometricNotEnrolled;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @usePassword.
  ///
  /// In en, this message translates to:
  /// **'Use password'**
  String get usePassword;

  /// No description provided for @validationFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'{label} is required'**
  String validationFieldRequired(String label);

  /// No description provided for @validationTooLong.
  ///
  /// In en, this message translates to:
  /// **'{label} must be {max} characters or fewer'**
  String validationTooLong(String label, int max);

  /// No description provided for @validationNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Name must be 40 characters or fewer'**
  String get validationNameTooLong;

  /// No description provided for @validationDuplicateMember.
  ///
  /// In en, this message translates to:
  /// **'That name is already in the list'**
  String get validationDuplicateMember;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get validationPasswordShort;

  /// No description provided for @validationPasswordLong.
  ///
  /// In en, this message translates to:
  /// **'Password must be 64 characters or fewer'**
  String get validationPasswordLong;

  /// No description provided for @validationInviteFormat.
  ///
  /// In en, this message translates to:
  /// **'Invite codes are 6 characters long'**
  String get validationInviteFormat;

  /// No description provided for @recordSettlement.
  ///
  /// In en, this message translates to:
  /// **'Record settlement'**
  String get recordSettlement;

  /// No description provided for @pays.
  ///
  /// In en, this message translates to:
  /// **'pays'**
  String get pays;

  /// No description provided for @receives.
  ///
  /// In en, this message translates to:
  /// **'receives'**
  String get receives;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// No description provided for @confirmPayment.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment'**
  String get confirmPayment;

  /// No description provided for @settlementRecorded.
  ///
  /// In en, this message translates to:
  /// **'Settlement recorded'**
  String get settlementRecorded;

  /// No description provided for @toBeSettled.
  ///
  /// In en, this message translates to:
  /// **'To be settled'**
  String get toBeSettled;

  /// No description provided for @whoOwesWhom.
  ///
  /// In en, this message translates to:
  /// **'Who owes whom'**
  String get whoOwesWhom;

  /// No description provided for @settleHint.
  ///
  /// In en, this message translates to:
  /// **'You pay, then request settlement. The member you owe approves it before the balance updates.'**
  String get settleHint;

  /// No description provided for @settlementHistory.
  ///
  /// In en, this message translates to:
  /// **'Settlement history'**
  String get settlementHistory;

  /// No description provided for @allSettled.
  ///
  /// In en, this message translates to:
  /// **'All settled up!'**
  String get allSettled;

  /// No description provided for @allSettledMessage.
  ///
  /// In en, this message translates to:
  /// **'Everyone in this cycle is even. Nice teamwork.'**
  String get allSettledMessage;

  /// No description provided for @nothingToSettleTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to settle yet'**
  String get nothingToSettleTitle;

  /// No description provided for @noSettlementsMessage.
  ///
  /// In en, this message translates to:
  /// **'No expenses have been recorded in this cycle yet. Add your first expense and the who-owes-whom breakdown will appear here.'**
  String get noSettlementsMessage;

  /// No description provided for @settleAction.
  ///
  /// In en, this message translates to:
  /// **'Settle'**
  String get settleAction;

  /// No description provided for @requestSettlementTitle.
  ///
  /// In en, this message translates to:
  /// **'Request settlement'**
  String get requestSettlementTitle;

  /// No description provided for @requestSettlementAction.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get requestSettlementAction;

  /// No description provided for @creditorApprovalNote.
  ///
  /// In en, this message translates to:
  /// **'{name} must approve this request before the amount is marked as settled.'**
  String creditorApprovalNote(String name);

  /// No description provided for @maxOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Up to {amount}'**
  String maxOutstanding(String amount);

  /// No description provided for @pendingRequestsSection.
  ///
  /// In en, this message translates to:
  /// **'Pending approvals'**
  String get pendingRequestsSection;

  /// No description provided for @waitingApprovalFrom.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name} to approve'**
  String waitingApprovalFrom(String name);

  /// No description provided for @awaitingDebtorRequest.
  ///
  /// In en, this message translates to:
  /// **'{name} owes you — waiting for their settlement request'**
  String awaitingDebtorRequest(String name);

  /// No description provided for @statusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved · Settled'**
  String get statusApproved;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @requestAgain.
  ///
  /// In en, this message translates to:
  /// **'Request again'**
  String get requestAgain;

  /// No description provided for @settlementRequestedToast.
  ///
  /// In en, this message translates to:
  /// **'Settlement request sent to {name}'**
  String settlementRequestedToast(String name);

  /// No description provided for @settlementApprovedToast.
  ///
  /// In en, this message translates to:
  /// **'Settlement approved and recorded'**
  String get settlementApprovedToast;

  /// No description provided for @settlementRejectedToast.
  ///
  /// In en, this message translates to:
  /// **'Request rejected. You can send a new one.'**
  String get settlementRejectedToast;

  /// No description provided for @amountExceedsOutstanding.
  ///
  /// In en, this message translates to:
  /// **'The amount cannot exceed what you still owe.'**
  String get amountExceedsOutstanding;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'This name is shared with your space members.'**
  String get displayNameHint;

  /// No description provided for @enterNameError.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterNameError;

  /// No description provided for @space.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get space;

  /// No description provided for @spaceAndMembers.
  ///
  /// In en, this message translates to:
  /// **'Space & members'**
  String get spaceAndMembers;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @memberGroups.
  ///
  /// In en, this message translates to:
  /// **'Member Groups'**
  String get memberGroups;

  /// No description provided for @memberGroupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create groups to split as a single participant'**
  String get memberGroupsSubtitle;

  /// No description provided for @noMemberGroups.
  ///
  /// In en, this message translates to:
  /// **'No member groups yet'**
  String get noMemberGroups;

  /// No description provided for @noMemberGroupsDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a group to combine members into a single participant when splitting expenses.'**
  String get noMemberGroupsDescription;

  /// No description provided for @onlyOwnerCanCreateGroups.
  ///
  /// In en, this message translates to:
  /// **'Only the space owner can create member groups.'**
  String get onlyOwnerCanCreateGroups;

  /// No description provided for @requestGroup.
  ///
  /// In en, this message translates to:
  /// **'Request a group'**
  String get requestGroup;

  /// No description provided for @requestGroupDescription.
  ///
  /// In en, this message translates to:
  /// **'Ask the space owner to create a group containing you and the members you choose. Only the owner can create groups.'**
  String get requestGroupDescription;

  /// No description provided for @requestGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Member Group'**
  String get requestGroupTitle;

  /// No description provided for @requestGroupMembersHint.
  ///
  /// In en, this message translates to:
  /// **'Choose members to group with you. The group will be owned by you.'**
  String get requestGroupMembersHint;

  /// No description provided for @groupRequested.
  ///
  /// In en, this message translates to:
  /// **'Group request sent to the owner'**
  String get groupRequested;

  /// No description provided for @groupRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send group request'**
  String get groupRequestFailed;

  /// No description provided for @groupRequestAlreadyPending.
  ///
  /// In en, this message translates to:
  /// **'You already have a pending group request.'**
  String get groupRequestAlreadyPending;

  /// No description provided for @noMembersToRequest.
  ///
  /// In en, this message translates to:
  /// **'No other members are available to group with'**
  String get noMembersToRequest;

  /// No description provided for @requestGroupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Member groups need at least three members in this space.'**
  String get requestGroupUnavailable;

  /// No description provided for @pendingGroupRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending group requests'**
  String get pendingGroupRequests;

  /// No description provided for @pendingGroupRequestsDescription.
  ///
  /// In en, this message translates to:
  /// **'Members have asked you to create a group for them. Approving creates the group owned by the requester.'**
  String get pendingGroupRequestsDescription;

  /// No description provided for @pendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get pendingApproval;

  /// No description provided for @pendingApprovalSection.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get pendingApprovalSection;

  /// No description provided for @openByDefault.
  ///
  /// In en, this message translates to:
  /// **'Open by default next time'**
  String get openByDefault;

  /// No description provided for @defaultSpaceSetMessage.
  ///
  /// In en, this message translates to:
  /// **'{space} will open by default next time'**
  String defaultSpaceSetMessage(String space);

  /// No description provided for @defaultSpaceRemovedMessage.
  ///
  /// In en, this message translates to:
  /// **'No longer the default space'**
  String get defaultSpaceRemovedMessage;

  /// No description provided for @deleteSpace.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteSpace;

  /// No description provided for @leaveSpace.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveSpace;

  /// No description provided for @leaveBlockedOutstanding.
  ///
  /// In en, this message translates to:
  /// **'You have an outstanding balance. Settle your dues before leaving the space.'**
  String get leaveBlockedOutstanding;

  /// No description provided for @deletingSpaceIn.
  ///
  /// In en, this message translates to:
  /// **'Deleting {space} in {seconds}s'**
  String deletingSpaceIn(String space, int seconds);

  /// No description provided for @leavingSpaceIn.
  ///
  /// In en, this message translates to:
  /// **'Leaving {space} in {seconds}s'**
  String leavingSpaceIn(String space, int seconds);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @spaceActionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Action cancelled. Nothing changed.'**
  String get spaceActionCancelled;

  /// No description provided for @spaceDeleted.
  ///
  /// In en, this message translates to:
  /// **'Space deleted.'**
  String get spaceDeleted;

  /// No description provided for @spaceLeft.
  ///
  /// In en, this message translates to:
  /// **'You left the space.'**
  String get spaceLeft;

  /// No description provided for @yourGroupRequestPending.
  ///
  /// In en, this message translates to:
  /// **'Your group request is pending approval. You\'ll be notified once the space owner decides.'**
  String get yourGroupRequestPending;

  /// No description provided for @noPendingGroupRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending group requests'**
  String get noPendingGroupRequests;

  /// No description provided for @requestedBy.
  ///
  /// In en, this message translates to:
  /// **'Requested by'**
  String get requestedBy;

  /// No description provided for @groupRequestApproved.
  ///
  /// In en, this message translates to:
  /// **'Group created'**
  String get groupRequestApproved;

  /// No description provided for @groupRequestApprovedFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to approve request'**
  String get groupRequestApprovedFail;

  /// No description provided for @groupRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get groupRequestRejected;

  /// No description provided for @groupRequestRejectFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to reject request'**
  String get groupRequestRejectFail;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @groupCreationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Member groups need at least three members in this space.'**
  String get groupCreationUnavailable;

  /// No description provided for @alreadyInGroup.
  ///
  /// In en, this message translates to:
  /// **'You already belong to a member group.'**
  String get alreadyInGroup;

  /// No description provided for @createMemberGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Member Group'**
  String get createMemberGroup;

  /// No description provided for @createGroupDescription.
  ///
  /// In en, this message translates to:
  /// **'Select members to add to this group. The group will be owned by you.'**
  String get createGroupDescription;

  /// No description provided for @groupOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get groupOwner;

  /// No description provided for @youAreOwner.
  ///
  /// In en, this message translates to:
  /// **'You are the owner of this group'**
  String get youAreOwner;

  /// No description provided for @noOtherMembersToAdd.
  ///
  /// In en, this message translates to:
  /// **'No other space members to add'**
  String get noOtherMembersToAdd;

  /// No description provided for @managedByYou.
  ///
  /// In en, this message translates to:
  /// **'Managed by you'**
  String get managedByYou;

  /// No description provided for @managedBy.
  ///
  /// In en, this message translates to:
  /// **'Managed by'**
  String get managedBy;

  /// No description provided for @groupCreated.
  ///
  /// In en, this message translates to:
  /// **'Group created'**
  String get groupCreated;

  /// No description provided for @groupCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create group'**
  String get groupCreateFailed;

  /// No description provided for @deleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Group'**
  String get deleteGroupTitle;

  /// No description provided for @deleteGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'This group will be removed. Historical expenses using this group will not be affected.'**
  String get deleteGroupMessage;

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteGroup;

  /// No description provided for @groupDeleted.
  ///
  /// In en, this message translates to:
  /// **'Group deleted'**
  String get groupDeleted;

  /// No description provided for @groupDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete group'**
  String get groupDeleteFailed;

  /// No description provided for @addGroupMember.
  ///
  /// In en, this message translates to:
  /// **'Add Member'**
  String get addGroupMember;

  /// No description provided for @memberAdded.
  ///
  /// In en, this message translates to:
  /// **'Member added'**
  String get memberAdded;

  /// No description provided for @memberAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add member'**
  String get memberAddFailed;

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeMember;

  /// No description provided for @memberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get memberRemoved;

  /// No description provided for @memberRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove member'**
  String get memberRemoveFailed;

  /// No description provided for @removeGroupMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this group?'**
  String removeGroupMemberTitle(Object name);

  /// No description provided for @removeGroupMemberMessage.
  ///
  /// In en, this message translates to:
  /// **'They will no longer be part of this group. Historical expenses are not affected.'**
  String get removeGroupMemberMessage;

  /// No description provided for @groupCountsAsOneParticipant.
  ///
  /// In en, this message translates to:
  /// **'This group counts as one participant.'**
  String get groupCountsAsOneParticipant;

  /// No description provided for @noMembersAvailableToAdd.
  ///
  /// In en, this message translates to:
  /// **'No members available to add'**
  String get noMembersAvailableToAdd;

  /// No description provided for @groupFull.
  ///
  /// In en, this message translates to:
  /// **'This group has reached its maximum size. Remove a member before adding another.'**
  String get groupFull;

  /// No description provided for @groupMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupMembers;

  /// No description provided for @noMembersInGroup.
  ///
  /// In en, this message translates to:
  /// **'No members in this group yet'**
  String get noMembersInGroup;

  /// No description provided for @groupOwnerLabel.
  ///
  /// In en, this message translates to:
  /// **'Group Owner'**
  String get groupOwnerLabel;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @defaultCategories.
  ///
  /// In en, this message translates to:
  /// **'Default categories'**
  String get defaultCategories;

  /// No description provided for @customCategories.
  ///
  /// In en, this message translates to:
  /// **'Custom categories'**
  String get customCategories;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// No description provided for @categoryNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Kids, Pets, Gym'**
  String get categoryNameHint;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @colour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colour;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @enterCategoryNameError.
  ///
  /// In en, this message translates to:
  /// **'Enter a category name'**
  String get enterCategoryNameError;

  /// No description provided for @categoryTooLongError.
  ///
  /// In en, this message translates to:
  /// **'Keep it under 24 characters'**
  String get categoryTooLongError;

  /// No description provided for @duplicateCategoryError.
  ///
  /// In en, this message translates to:
  /// **'That category already exists'**
  String get duplicateCategoryError;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied'**
  String get inviteCodeCopied;

  /// No description provided for @shareInviteHint.
  ///
  /// In en, this message translates to:
  /// **'Share this code so friends and roommates can join your space.'**
  String get shareInviteHint;

  /// No description provided for @inviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite a member'**
  String get inviteMember;

  /// No description provided for @inviteMemberHint.
  ///
  /// In en, this message translates to:
  /// **'person@example.com'**
  String get inviteMemberHint;

  /// No description provided for @inviteMemberHelper.
  ///
  /// In en, this message translates to:
  /// **'An invitation email is sent to the address. Invited members appear in expense splits.'**
  String get inviteMemberHelper;

  /// Toast after a member is invited by email
  ///
  /// In en, this message translates to:
  /// **'{email} invited to the space'**
  String invitedMember(String email);

  /// No description provided for @inviteMemberAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'That email already belongs to a member of this space'**
  String get inviteMemberAlreadyMember;

  /// No description provided for @duplicateEmailError.
  ///
  /// In en, this message translates to:
  /// **'That email is already in the list'**
  String get duplicateEmailError;

  /// No description provided for @pendingJoinRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending join requests'**
  String get pendingJoinRequests;

  /// No description provided for @pendingJoinRequestsDescription.
  ///
  /// In en, this message translates to:
  /// **'Members have asked to join this space. Approving adds them to the space.'**
  String get pendingJoinRequestsDescription;

  /// No description provided for @joinRequestPendingDescription.
  ///
  /// In en, this message translates to:
  /// **'Your request to join this space is pending approval. You\'ll be able to enter the space once the owner approves it.'**
  String get joinRequestPendingDescription;

  /// No description provided for @joinRequestApproved.
  ///
  /// In en, this message translates to:
  /// **'Join request approved'**
  String get joinRequestApproved;

  /// No description provided for @joinRequestApprovedFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to approve request'**
  String get joinRequestApprovedFail;

  /// No description provided for @joinRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Join request rejected'**
  String get joinRequestRejected;

  /// No description provided for @joinRequestRejectFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to reject request'**
  String get joinRequestRejectFail;

  /// No description provided for @wantsToJoinSpace.
  ///
  /// In en, this message translates to:
  /// **'wants to join this space'**
  String get wantsToJoinSpace;

  /// No description provided for @addMemberFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get addMemberFieldHint;

  /// No description provided for @addMemberHelper.
  ///
  /// In en, this message translates to:
  /// **'Members you add will appear in expense splits automatically.'**
  String get addMemberHelper;

  /// No description provided for @removeMemberMessage.
  ///
  /// In en, this message translates to:
  /// **'Their past expenses stay in the history, but they will no longer see this space.'**
  String get removeMemberMessage;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to settle'**
  String get statusReady;

  /// No description provided for @statusSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get statusSettled;

  /// No description provided for @statusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get statusClosed;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusPartiallyPaid.
  ///
  /// In en, this message translates to:
  /// **'Partially paid'**
  String get statusPartiallyPaid;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @spendingCycle.
  ///
  /// In en, this message translates to:
  /// **'Spending cycle'**
  String get spendingCycle;

  /// No description provided for @currentCycle.
  ///
  /// In en, this message translates to:
  /// **'Current cycle'**
  String get currentCycle;

  /// No description provided for @noActiveCycle.
  ///
  /// In en, this message translates to:
  /// **'No active cycle'**
  String get noActiveCycle;

  /// No description provided for @ownersCanManage.
  ///
  /// In en, this message translates to:
  /// **'Owners can manage cycles'**
  String get ownersCanManage;

  /// No description provided for @closeCurrentCycle.
  ///
  /// In en, this message translates to:
  /// **'Close current cycle'**
  String get closeCurrentCycle;

  /// No description provided for @startNewCycle.
  ///
  /// In en, this message translates to:
  /// **'Start a new cycle'**
  String get startNewCycle;

  /// No description provided for @closeCycle.
  ///
  /// In en, this message translates to:
  /// **'Close cycle'**
  String get closeCycle;

  /// No description provided for @closeCycleMessage.
  ///
  /// In en, this message translates to:
  /// **'The cycle becomes read-only and historical. A new cycle can be started afterwards.'**
  String get closeCycleMessage;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @csvOfCurrentCycle.
  ///
  /// In en, this message translates to:
  /// **'CSV of the current cycle'**
  String get csvOfCurrentCycle;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses, balances & reminders'**
  String get notificationsSubtitle;

  /// No description provided for @notificationsSheet.
  ///
  /// In en, this message translates to:
  /// **'In-app notifications keep you up to date without needing push.'**
  String get notificationsSheet;

  /// No description provided for @notificationExpenseAdded.
  ///
  /// In en, this message translates to:
  /// **'An expense was added'**
  String get notificationExpenseAdded;

  /// No description provided for @notificationExpenseUpdated.
  ///
  /// In en, this message translates to:
  /// **'An expense was updated'**
  String get notificationExpenseUpdated;

  /// No description provided for @notificationSettlementRecorded.
  ///
  /// In en, this message translates to:
  /// **'A settlement was recorded'**
  String get notificationSettlementRecorded;

  /// No description provided for @notificationHissaIncomeAdded.
  ///
  /// In en, this message translates to:
  /// **'A hissa income was recorded'**
  String get notificationHissaIncomeAdded;

  /// No description provided for @notificationHissaIncomeUpdated.
  ///
  /// In en, this message translates to:
  /// **'A hissa income was updated'**
  String get notificationHissaIncomeUpdated;

  /// No description provided for @notificationSettlementRequested.
  ///
  /// In en, this message translates to:
  /// **'A settlement request awaits your approval'**
  String get notificationSettlementRequested;

  /// No description provided for @notificationSettlementApproved.
  ///
  /// In en, this message translates to:
  /// **'Your settlement request was approved'**
  String get notificationSettlementApproved;

  /// No description provided for @notificationSettlementRejected.
  ///
  /// In en, this message translates to:
  /// **'Your settlement request was declined'**
  String get notificationSettlementRejected;

  /// No description provided for @notificationSpaceInvited.
  ///
  /// In en, this message translates to:
  /// **'You were invited to a Space'**
  String get notificationSpaceInvited;

  /// No description provided for @notificationSpaceJoinRequested.
  ///
  /// In en, this message translates to:
  /// **'A new join request awaits your approval'**
  String get notificationSpaceJoinRequested;

  /// No description provided for @notificationSpaceJoinApproved.
  ///
  /// In en, this message translates to:
  /// **'Your join request was approved'**
  String get notificationSpaceJoinApproved;

  /// No description provided for @notificationSpaceJoinRejected.
  ///
  /// In en, this message translates to:
  /// **'Your join request was declined'**
  String get notificationSpaceJoinRejected;

  /// No description provided for @notificationGroupRequested.
  ///
  /// In en, this message translates to:
  /// **'A new group request awaits your approval'**
  String get notificationGroupRequested;

  /// No description provided for @notificationGroupApproved.
  ///
  /// In en, this message translates to:
  /// **'Your group request was approved'**
  String get notificationGroupApproved;

  /// No description provided for @notificationGroupRejected.
  ///
  /// In en, this message translates to:
  /// **'Your group request was declined'**
  String get notificationGroupRejected;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @noNotificationsMessage.
  ///
  /// In en, this message translates to:
  /// **'Activity in your Spaces and requests will show up here.'**
  String get noNotificationsMessage;

  /// No description provided for @inSpace.
  ///
  /// In en, this message translates to:
  /// **'in a Space'**
  String get inSpace;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @onValue.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get onValue;

  /// No description provided for @offValue.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get offValue;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch account or space'**
  String get signOutSubtitle;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutMessage.
  ///
  /// In en, this message translates to:
  /// **'You can sign back in at any time.'**
  String get signOutMessage;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Hissa · Space Expense Tracker'**
  String get appName;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'v1.0.0'**
  String get version;

  /// No description provided for @newCycleStarted.
  ///
  /// In en, this message translates to:
  /// **'New cycle started'**
  String get newCycleStarted;

  /// No description provided for @cycleClosed.
  ///
  /// In en, this message translates to:
  /// **'Cycle closed'**
  String get cycleClosed;

  /// No description provided for @settleBeforeClose.
  ///
  /// In en, this message translates to:
  /// **'Settle all balances before closing the cycle'**
  String get settleBeforeClose;

  /// No description provided for @csvExport.
  ///
  /// In en, this message translates to:
  /// **'CSV export'**
  String get csvExport;

  /// No description provided for @currentCycleFallback.
  ///
  /// In en, this message translates to:
  /// **'Current cycle'**
  String get currentCycleFallback;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @copyCsv.
  ///
  /// In en, this message translates to:
  /// **'Copy CSV to clipboard'**
  String get copyCsv;

  /// No description provided for @csvCopied.
  ///
  /// In en, this message translates to:
  /// **'CSV copied to clipboard'**
  String get csvCopied;

  /// No description provided for @shareReport.
  ///
  /// In en, this message translates to:
  /// **'Share report'**
  String get shareReport;

  /// No description provided for @csvCopiedShare.
  ///
  /// In en, this message translates to:
  /// **'CSV copied - paste it anywhere to share'**
  String get csvCopiedShare;

  /// No description provided for @emptyPreview.
  ///
  /// In en, this message translates to:
  /// **'…'**
  String get emptyPreview;

  /// No description provided for @noExpensesForExport.
  ///
  /// In en, this message translates to:
  /// **'No expenses to export yet'**
  String get noExpensesForExport;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App display language'**
  String get languageSubtitle;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @nepali.
  ///
  /// In en, this message translates to:
  /// **'Nepali'**
  String get nepali;

  /// No description provided for @expenseAmountError.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than 0.'**
  String get expenseAmountError;

  /// No description provided for @expenseDescriptionError.
  ///
  /// In en, this message translates to:
  /// **'Add a short description.'**
  String get expenseDescriptionError;

  /// No description provided for @expensePayerError.
  ///
  /// In en, this message translates to:
  /// **'Choose who paid.'**
  String get expensePayerError;

  /// No description provided for @expenseParticipantError.
  ///
  /// In en, this message translates to:
  /// **'Select at least one participant.'**
  String get expenseParticipantError;

  /// No description provided for @hissaIncome.
  ///
  /// In en, this message translates to:
  /// **'Hissa income'**
  String get hissaIncome;

  /// No description provided for @addIncome.
  ///
  /// In en, this message translates to:
  /// **'Add income'**
  String get addIncome;

  /// No description provided for @editIncome.
  ///
  /// In en, this message translates to:
  /// **'Edit income'**
  String get editIncome;

  /// No description provided for @incomeDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get incomeDescriptionLabel;

  /// No description provided for @incomeDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Room rent, refund, subsidy'**
  String get incomeDescriptionHint;

  /// No description provided for @receivedBy.
  ///
  /// In en, this message translates to:
  /// **'Received by'**
  String get receivedBy;

  /// No description provided for @receivedByHint.
  ///
  /// In en, this message translates to:
  /// **'Who physically received this money?'**
  String get receivedByHint;

  /// No description provided for @incomeSplitNote.
  ///
  /// In en, this message translates to:
  /// **'{name} received this money for the hissa. Its benefit is split across the selected members and lowers everyone\'s share of the net expense.'**
  String incomeSplitNote(String name);

  /// No description provided for @saveIncome.
  ///
  /// In en, this message translates to:
  /// **'Save income'**
  String get saveIncome;

  /// No description provided for @incomeAddedToast.
  ///
  /// In en, this message translates to:
  /// **'Hissa income recorded'**
  String get incomeAddedToast;

  /// No description provided for @incomeUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Hissa income updated'**
  String get incomeUpdatedToast;

  /// No description provided for @incomeDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'Hissa income deleted'**
  String get incomeDeletedToast;

  /// No description provided for @deleteIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this hissa income?'**
  String get deleteIncomeTitle;

  /// No description provided for @deleteIncomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Balances will be recalculated without this contribution.'**
  String get deleteIncomeMessage;

  /// No description provided for @netExpense.
  ///
  /// In en, this message translates to:
  /// **'Net hissa expense'**
  String get netExpense;

  /// No description provided for @hissaIncomeSection.
  ///
  /// In en, this message translates to:
  /// **'Hissa income'**
  String get hissaIncomeSection;

  /// No description provided for @receivedByMemberDay.
  ///
  /// In en, this message translates to:
  /// **'Received by {name} · {day}'**
  String receivedByMemberDay(String name, String day);

  /// No description provided for @expensePercentError.
  ///
  /// In en, this message translates to:
  /// **'Percentages must add up to 100%.'**
  String get expensePercentError;

  /// No description provided for @expenseCustomError.
  ///
  /// In en, this message translates to:
  /// **'Custom amounts must add up to the total.'**
  String get expenseCustomError;

  /// No description provided for @expenseSharesError.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one share unit.'**
  String get expenseSharesError;

  /// No description provided for @chooseCycleType.
  ///
  /// In en, this message translates to:
  /// **'Spending cycle'**
  String get chooseCycleType;

  /// No description provided for @monthlyCycle.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthlyCycle;

  /// No description provided for @monthlyCycleDescription.
  ///
  /// In en, this message translates to:
  /// **'Tracks the running month automatically'**
  String get monthlyCycleDescription;

  /// No description provided for @customCycle.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customCycle;

  /// No description provided for @customCycleDescription.
  ///
  /// In en, this message translates to:
  /// **'An open-ended cycle you manage'**
  String get customCycleDescription;

  /// No description provided for @renameCycle.
  ///
  /// In en, this message translates to:
  /// **'Rename cycle'**
  String get renameCycle;

  /// No description provided for @renameCycleTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename cycle'**
  String get renameCycleTitle;

  /// No description provided for @cycleName.
  ///
  /// In en, this message translates to:
  /// **'Cycle name'**
  String get cycleName;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @cycleRenamed.
  ///
  /// In en, this message translates to:
  /// **'Cycle renamed'**
  String get cycleRenamed;

  /// No description provided for @previousCycles.
  ///
  /// In en, this message translates to:
  /// **'Previous cycles'**
  String get previousCycles;

  /// No description provided for @previousCyclesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} closed cycles'**
  String previousCyclesCount(int count);

  /// No description provided for @cycleDetails.
  ///
  /// In en, this message translates to:
  /// **'Cycle details'**
  String get cycleDetails;

  /// No description provided for @spentLabel.
  ///
  /// In en, this message translates to:
  /// **'spent'**
  String get spentLabel;

  /// No description provided for @expensesCount.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesCount;

  /// No description provided for @noExpensesInCycle.
  ///
  /// In en, this message translates to:
  /// **'No expenses recorded in this cycle.'**
  String get noExpensesInCycle;

  /// No description provided for @noPreviousCycles.
  ///
  /// In en, this message translates to:
  /// **'No previous cycles yet.'**
  String get noPreviousCycles;

  /// No description provided for @cycleStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get cycleStatusActive;

  /// No description provided for @cycleStatusReadyToSettle.
  ///
  /// In en, this message translates to:
  /// **'Ready to settle'**
  String get cycleStatusReadyToSettle;

  /// No description provided for @cycleStatusSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get cycleStatusSettled;

  /// No description provided for @cycleStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get cycleStatusClosed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ne'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ne':
      return AppLocalizationsNe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
