import 'package:intl/intl.dart';

/// Centralized formatting helpers for the entire app.
/// All screens should use these instead of ad-hoc `.toStringAsFixed()`.
class AppFormatters {
  // ─── Currency ───────────────────────────────────────────────────────────────

  static final _currencyFormat = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'ج.م',
    decimalDigits: 2,
  );

  /// e.g. 1,234.50 ج.م
  static String currency(double amount, {String? symbol}) {
    if (symbol != null) {
      final fmt = NumberFormat.currency(locale: 'ar_EG', symbol: symbol, decimalDigits: 2);
      return fmt.format(amount);
    }
    return _currencyFormat.format(amount);
  }

  /// Short form: 1,234 ج (no decimals) — good for large totals on cards
  static String currencyCompact(double amount, {String symbol = 'ج'}) {
    return '${NumberFormat('#,###', 'ar_EG').format(amount)} $symbol';
  }

  // ─── Percentage ─────────────────────────────────────────────────────────────

  /// e.g. 14.00%
  static String percent(double value) =>
      '${value.toStringAsFixed(2)}%';

  // ─── Dates ──────────────────────────────────────────────────────────────────

  static final _dateFormat = DateFormat('yyyy/MM/dd', 'ar_EG');
  static final _dateTimeFormat = DateFormat('yyyy/MM/dd  hh:mm a', 'ar_EG');
  static final _shortTimeFormat = DateFormat('hh:mm a', 'ar_EG');

  /// e.g. 2024/02/24
  static String date(DateTime dt) => _dateFormat.format(dt.toLocal());

  /// e.g. 2024/02/24  09:30 ص
  static String dateTime(DateTime dt) => _dateTimeFormat.format(dt.toLocal());

  /// e.g. 09:30 ص
  static String time(DateTime dt) => _shortTimeFormat.format(dt.toLocal());

  /// Human-friendly relative date: "اليوم", "أمس", otherwise full date
  static String relativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    return date(dt);
  }

  // ─── Numbers ─────────────────────────────────────────────────────────────────

  /// Compact number: 1,500 → "1.5K", 1,500,000 → "1.5M"
  static String compact(double value) =>
      NumberFormat.compact(locale: 'ar_EG').format(value);

  /// Integer with thousands separator: 12345 → "12,345"
  static String integer(int value) =>
      NumberFormat('#,###', 'ar_EG').format(value);
}
