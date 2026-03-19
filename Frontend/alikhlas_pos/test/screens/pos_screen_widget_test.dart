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
import 'package:alikhlas_pos/models/user_model.dart';
import 'package:alikhlas_pos/controllers/auth_controller.dart';
import 'package:alikhlas_pos/controllers/notifications_controller.dart';
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
  
  @override
  RxDouble get globalDiscount => 0.0.obs;
  
  @override
  double get total => 100.0;
  
  @override
  bool get hasLastReceipt => false;
  
  @override
  Rx<PaymentType> get selectedPaymentType => PaymentType.cash.obs;
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

class FakeAuthController extends AuthController {
  @override
  void onInit() {}
  
  @override
  Rxn<UserModel> get currentUser => Rxn<UserModel>(UserModel(
        id: '1', username: 'testuser', fullName: 'Test Use', role: 'admin'));
}

class FakeNotificationsController extends NotificationsController {
  @override
  void onInit() {}
  
  @override
  RxInt get unreadCount => 0.obs;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
  });

  group('POS Screen Widget Tests (Keyboard Shortcuts)', () {
    late FakePosController fakePosController;
    late FakeShiftController fakeShiftController;
    late FakeAuthController fakeAuthController;
    late FakeNotificationsController fakeNotificationsController;
    
    setUp(() {
      Get.testMode = true;
      fakePosController = FakePosController();
      fakeShiftController = FakeShiftController();
      fakeAuthController = FakeAuthController();
      fakeNotificationsController = FakeNotificationsController();
      
      Get.put<PosController>(fakePosController);
      Get.put<ShiftController>(fakeShiftController);
      Get.put<AuthController>(fakeAuthController);
      Get.put<NotificationsController>(fakeNotificationsController);
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
