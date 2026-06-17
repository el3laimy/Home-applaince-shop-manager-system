import 'package:intl/intl.dart';

class Money implements Comparable<Money> {
  const Money(this.minorUnits);

  static const zero = Money(0);

  final int minorUnits;

  factory Money.egp(num amount) => Money((amount * 100).round());

  Money operator +(Money other) => Money(minorUnits + other.minorUnits);
  Money operator -(Money other) => Money(minorUnits - other.minorUnits);
  Money operator -() => Money(-minorUnits);
  Money operator *(int factor) => Money(minorUnits * factor);

  bool get isZero => minorUnits == 0;
  bool get isPositive => minorUnits > 0;
  bool get isNegative => minorUnits < 0;

  String format({String symbol = 'ج.م'}) {
    final value = minorUnits / 100;
    final formatted = NumberFormat.currency(
      locale: 'ar_EG',
      symbol: symbol,
      decimalDigits: 2,
    ).format(value);
    return formatted;
  }

  @override
  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  @override
  String toString() => format();
}

int allocateRemainderToLast(int totalMinorUnits, int count, int index) {
  if (count <= 0) {
    throw ArgumentError.value(
      count,
      'count',
      'Installment count must be positive.',
    );
  }
  final base = totalMinorUnits ~/ count;
  final remainder = totalMinorUnits - (base * count);
  return index == count - 1 ? base + remainder : base;
}
