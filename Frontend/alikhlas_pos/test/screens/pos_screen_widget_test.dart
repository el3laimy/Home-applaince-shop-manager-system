import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:alikhlas_pos/screens/pos_screen.dart';
import 'package:alikhlas_pos/controllers/pos_controller.dart';
import 'package:alikhlas_pos/controllers/shift_controller.dart';
import 'package:alikhlas_pos/models/shift_model.dart';
import 'package:alikhlas_pos/models/product_model.dart';
import 'package:alikhlas_pos/models/invoice_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FakePosController extends PosController {
  @override
  void onInit() {}
  
  bool checkoutCalled = false;
  
  // Dummy cart items to allow discount dialog to show (requires cart not empty)
  @override
  RxList<CartItemModel> get cartItems => <CartItemModel>[
    CartItemModel(
      barcode: '123',
      productId: '1', 
      productName: 'TestItem', 
      unitPrice: 100, 
      quantity: 1
    )
  ].obs;
  
  @override
  double get cartTotal => 100.0;
}

class FakeShiftController extends ShiftController {
  @override
  void onInit() {}
  
  @override
  RxBool get hasActiveShift => true.obs;
  
  @override
  Rxn<Shift> get currentShift => Rxn<Shift>(Shift(
        id: '1', cashierId: '1', startTime: DateTime.now(),
        openingCash: 100, expectedCash: 100, status: 0,
        totalSales: 0, totalCashIn: 0, totalCashOut: 0,
        actualCash: 0, difference: 0, notes: ''
      ));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
  });

  group('POS Screen Widget Tests (Keyboard Shortcuts)', () {
    late FakePosController fakePosController;
    late FakeShiftController fakeShiftController;
    
    setUp(() {
      Get.testMode = true;
      fakePosController = FakePosController();
      fakeShiftController = FakeShiftController();
      
      Get.put<PosController>(fakePosController);
      Get.put<ShiftController>(fakeShiftController);
    });

    tearDown(() {
      Get.reset(); // Clear GetX bindings after each test
    });

    Widget createWidgetUnderTest(WidgetTester tester) {
      tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      
      return const GetMaterialApp(
        home: Scaffold(body: PosScreen()),
      );
    }

    testWidgets('POS Screen renders main components', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(tester));
      await tester.pumpAndSettle();

      expect(find.byType(PosScreen), findsOneWidget);
      expect(find.text('TestItem'), findsWidgets); // Cart item is rendered
    });
  });
}
