part of '../v2_use_cases.dart';

Map<int, List<T>> _groupIntegrityRows<T>(
  Iterable<T> rows,
  int Function(T row) keyOf,
) {
  final grouped = <int, List<T>>{};
  for (final row in rows) {
    grouped.putIfAbsent(keyOf(row), () => []).add(row);
  }
  return grouped;
}
