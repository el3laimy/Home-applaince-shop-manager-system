import 'package:alikhlas_pos/v2/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('stores amounts as integer minor units', () {
      expect(const Money(1025).minorUnits, 1025);
      expect((const Money(1250) + const Money(250)).minorUnits, 1500);
      expect((const Money(1250) - const Money(250)).minorUnits, 1000);
    });

    test('parses money input without double arithmetic', () {
      expect(parseMoneyInput('125').minorUnits, 12500);
      expect(parseMoneyInput('125.5').minorUnits, 12550);
      expect(parseMoneyInput('125,50').minorUnits, 12550);
      expect(parseMoneyInput('١٢٥,٥٠').minorUnits, 12550);
      expect(parseMoneyInput('۱۲۵.۵۰').minorUnits, 12550);
    });

    test('formats plain money without hidden bidi marks for pdf output', () {
      final text = const Money(1500000).formatPlain();

      expect(text, '15,000.00 ج.م');
      expect(text, isNot(contains('\u200f')));
      expect(text, isNot(contains('\u061c')));
    });

    test('rejects ambiguous or invalid money input', () {
      expect(parseMoneyInput('125.555').isValid, isFalse);
      expect(parseMoneyInput('125.50.10').isValid, isFalse);
      expect(parseMoneyInput('abc').isValid, isFalse);
      expect(parseMoneyInput('-1').isValid, isFalse);
      expect(parseMoneyInput('-1', allowNegative: true).minorUnits, -100);
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
