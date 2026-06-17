import 'package:alikhlas_pos/v2/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('stores amounts as integer minor units', () {
      expect(Money.egp(10.25).minorUnits, 1025);
      expect((const Money(1250) + const Money(250)).minorUnits, 1500);
      expect((const Money(1250) - const Money(250)).minorUnits, 1000);
    });

    test('allocates installment rounding difference to the last payment', () {
      final payments = [
        for (var index = 0; index < 3; index++)
          allocateRemainderToLast(10001, 3, index),
      ];

      expect(payments, [3333, 3333, 3335]);
      expect(payments.reduce((a, b) => a + b), 10001);
    });
  });
}
