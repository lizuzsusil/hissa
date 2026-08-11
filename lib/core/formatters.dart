import 'package:intl/intl.dart';

import 'money.dart';

/// Formats a [Money] value as NPR, e.g. "Rs. 1,234.50".
String formatMoney(Money money, {bool showSymbol = true}) {
  final value = money.paisa.abs() / 100;
  final formatted = _nprFormat.format(value);
  final prefix = money.isNegative ? '-Rs. ' : 'Rs. ';
  if (!showSymbol) {
    return '${money.isNegative ? '-' : ''}$formatted';
  }
  return '$prefix$formatted';
}

/// Formats without paisa when the value is a whole number, e.g. "Rs. 1,250".
String formatMoneyCompact(Money money, {bool showSymbol = true}) {
  final value = money.paisa.abs() / 100;
  final isWhole = value == value.roundToDouble();
  final formatted = isWhole ? _nprWhole.format(value) : _nprFormat.format(value);
  final prefix = money.isNegative ? '-Rs. ' : 'Rs. ';
  if (!showSymbol) {
    return '${money.isNegative ? '-' : ''}$formatted';
  }
  return '$prefix$formatted';
}

String formatMajor(double value, {bool showSymbol = false}) {
  final formatted = _nprFormat.format(value.abs());
  final prefix = value < 0 ? '-Rs. ' : 'Rs. ';
  if (!showSymbol) {
    return '${value < 0 ? '-' : ''}$formatted';
  }
  return '$prefix$formatted';
}

String formatPercent(double value) => '${_pctFormat.format(value)}%';

final NumberFormat _nprFormat = NumberFormat.currency(
  symbol: '',
  decimalDigits: 2,
  locale: 'en_IN',
);

final NumberFormat _nprWhole = NumberFormat.currency(
  symbol: '',
  decimalDigits: 0,
  locale: 'en_IN',
);

final NumberFormat _pctFormat = NumberFormat.decimalPattern('en_IN');

final DateFormat _dayMonth = DateFormat('d MMM');
final DateFormat _fullDate = DateFormat('EEEE, d MMMM');
final DateFormat _shortDate = DateFormat('d MMM yyyy');
final DateFormat _monthName = DateFormat('MMMM');
final DateFormat _monthShort = DateFormat('MMM');
final DateFormat _monthYear = DateFormat('MMMM yyyy');
final DateFormat _year = DateFormat('yyyy');

String formatDay(DateTime date) => _dayMonth.format(date);
String formatFullDate(DateTime date) => _fullDate.format(date);
String formatShortDate(DateTime date) => _shortDate.format(date);
String formatMonthName(DateTime date) => _monthName.format(date);
String formatMonthShort(DateTime date) => _monthShort.format(date);
String formatMonthYear(DateTime date) => _monthYear.format(date);
String formatYear(DateTime date) => _year.format(date);

/// Returns a friendly label for a [DateTime] relative to today.
String formatRelativeDay(DateTime date) {
  final today = DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return formatDay(date);
  return formatShortDate(date);
}

/// Groups a list by a key; preserves first-seen order.
Map<String, List<T>> groupBy<T>(Iterable<T> items, String Function(T) keyFn) {
  final map = <String, List<T>>{};
  final order = <String>[];
  for (final item in items) {
    final key = keyFn(item);
    if (!map.containsKey(key)) {
      map[key] = <T>[];
      order.add(key);
    }
    map[key]!.add(item);
  }
  return map;
}

/// Formats a first name / initial from a full name.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first[0].toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
