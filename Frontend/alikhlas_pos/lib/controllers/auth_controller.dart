import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../core/widgets/main_shell.dart';
import '../screens/login_screen.dart';

class AuthController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isAuthenticated = false.obs;
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  
  @override
  void onInit() {
    super.onInit();
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token != null && token.isNotEmpty) {
      final username = prefs.getString('user_username') ?? '';
      final fullName = prefs.getString('user_fullname') ?? '';
      final role = prefs.getString('user_role') ?? 'Cashier';
      final id = prefs.getString('user_id') ?? '';
      
      currentUser.value = UserModel(id: id, username: username, fullName: fullName, role: role);
      ApiService.setToken(token);
      isAuthenticated.value = true;
    } else {
      isAuthenticated.value = false;
      ApiService.setToken(null);
    }
  }

  Future<bool> login(String username, String password, BuildContext context) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      _snapError(context, 'يرجى إدخال اسم المستخدم وكلمة المرور');
      return false;
    }

    isLoading.value = true;
    try {
      final response = await ApiService.post('auth/login', {
        'username': username.trim(),
        'password': password.trim(),
      });

      final token = response['token'] as String;
      final userMap = response['user'] as Map<String, dynamic>;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_id', userMap['id'] ?? '');
      await prefs.setString('user_username', userMap['username'] ?? '');
      await prefs.setString('user_fullname', userMap['fullName'] ?? '');
      await prefs.setString('user_role', userMap['role'] ?? 'Cashier');

      ApiService.setToken(token);
      currentUser.value = UserModel.fromJson(userMap);
      isAuthenticated.value = true;
      
      Get.offAll(() => const MainShell());
      return true;
    } on ApiException catch (e) {
      _snapError(context, e.message);
      return false;
    } catch (_) {
      _snapError(context, 'خطأ في الاتصال بالخادم');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ApiService.setToken(null);
    isAuthenticated.value = false;
    currentUser.value = null;
    Get.offAll(() => const LoginScreen());
  }

  void _snapError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
