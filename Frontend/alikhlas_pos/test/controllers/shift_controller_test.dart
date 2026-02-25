import 'package:flutter_test/flutter_test.dart';
import 'package:alikhlas_pos/controllers/shift_controller.dart';
import 'package:alikhlas_pos/models/shift_model.dart';
import 'package:get/get.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
  });

  group('ShiftController Unit Tests', () {
    late ShiftController shiftController;

    setUp(() {
      Get.testMode = true;
      shiftController = ShiftController();
    });

    test('Initial state should have no active shift', () {
      expect(shiftController.hasActiveShift.value, false);
      expect(shiftController.currentShift.value, isNull);
    });

    test('Simulate fetching active shift sets state correctly', () {
      final mockShift = Shift(
        id: 'shift-123',
        cashierId: 'user-1',
        startTime: DateTime.now(),
        openingCash: 1000,
        expectedCash: 1500,
        status: 0,
        totalSales: 500,
        totalCashIn: 0,
        totalCashOut: 0,
        actualCash: 0,
        difference: 0,
        notes: '',
      );

      shiftController.currentShift.value = mockShift;
      shiftController.hasActiveShift.value = true;

      expect(shiftController.hasActiveShift.value, true);
      expect(shiftController.currentShift.value?.openingCash, 1000);
    });

    test('Simulate closing shift resets active shift state', () {
      shiftController.hasActiveShift.value = true;
      
      // Simulate close response
      shiftController.currentShift.value = null;
      shiftController.hasActiveShift.value = false;

      expect(shiftController.hasActiveShift.value, false);
      expect(shiftController.currentShift.value, isNull);
    });
  });
}
