// Basic smoke test for the ALIkhlasPOS app
// Verifies that the app launches and shows the login screen

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:alikhlas_pos/screens/login_screen.dart';
import 'package:alikhlas_pos/controllers/auth_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(AuthController());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('LoginScreen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const LoginScreen(),
        textDirection: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    // Verify key login elements exist
    expect(find.text('إخلاص ERP'), findsOneWidget);
    expect(find.text('تسجيل الدخول للنظام'), findsOneWidget);
    expect(find.text('دخول'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // username + password
  });

  testWidgets('LoginScreen has username and password fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const LoginScreen(),
        textDirection: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();

    // Find text fields
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    // Verify can type in username field
    await tester.enterText(textFields.first, 'admin');
    expect(find.text('admin'), findsOneWidget);
  });
}
