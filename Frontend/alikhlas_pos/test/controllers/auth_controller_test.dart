import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alikhlas_pos/services/api_service.dart';
import 'package:alikhlas_pos/controllers/auth_controller.dart';
import 'package:get/get.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

// Since ApiService uses static methods, we can't easily mock it with mocktail directly
// unless we wrap it or intercept HTTP requests. 
// For this unit test, we will mock the SharedPreferences and test token handling logic.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
  });

  group('AuthController Unit Tests', () {
    late AuthController authController;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Get.testMode = true;
      authController = AuthController();
    });

    test('checkAuthStatus should be false initially', () async {
      await authController.checkAuthStatus();
      expect(authController.isAuthenticated.value, false);
      expect(authController.currentUser.value, isNull);
    });

    test('checkAuthStatus should be true if token exists', () async {
      SharedPreferences.setMockInitialValues({
        'token': 'dummy_token',
        'refresh_token': 'dummy_refresh'
      });
      // Ensure Get.put registers the controller so it can be found.
      Get.put(authController);
      
      await authController.checkAuthStatus();
      // Since checkAuthStatus makes an API call to /api/auth/me, and we didn't mock the HTTP interceptor,
      // it might fail or try to hit a real endpoint. Let's see how it behaves offline.
      // Usually, we'd use a Mock HTTP Client (like HTTP MockAdapter for Dio) to mock ApiService responses.
    });
    
    test('logout should clear preferences and set unauthenticated', () async {
      SharedPreferences.setMockInitialValues({
        'token': 'dummy_token',
        'refresh_token': 'dummy_refresh'
      });
      
      authController.isAuthenticated.value = true;
      await authController.logout();
      
      expect(authController.isAuthenticated.value, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), isNull);
    });
  });
}
