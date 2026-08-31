import 'package:intl/intl.dart';

/// Currency formatting bound to the shop's chosen symbol.
class Money {
  const Money(this.symbol);

  final String symbol;

  String format(num value) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: symbol,
        decimalDigits: 2,
      ).format(value);

  String compact(num value) => NumberFormat.compactCurrency(
        locale: 'en_IN',
        symbol: symbol,
        decimalDigits: 1,
      ).format(value);
}

String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff == -1) return 'Tomorrow';
  return DateFormat('EEE, d MMM yyyy').format(d);
}

String monthLabel(DateTime d) => DateFormat('MMMM yyyy').format(d);

String shortMonth(DateTime d) => DateFormat('MMM').format(d);

String shortDate(DateTime d) => DateFormat('d MMM').format(d);

String timeLabel(DateTime d) => DateFormat('h:mm a').format(d);
