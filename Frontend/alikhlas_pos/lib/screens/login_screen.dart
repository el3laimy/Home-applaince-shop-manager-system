import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/auth_controller.dart';
import '../core/theme/app_theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authCtrl = Get.put(AuthController());
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withAlpha(isDark ? 30 : 60)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 60 : 10),
                        blurRadius: 30, offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.diamond_rounded, size: 60, color: AppTheme.primaryColor),
                      ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
                      
                      const SizedBox(height: 24),
                      Text('إخلاص ERP', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 8),
                      Text('تسجيل الدخول للنظام', style: TextStyle(color: Colors.grey[500])).animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 40),

                      // Username Input
                      TextField(
                        controller: usernameCtrl,
                        decoration: InputDecoration(
                          labelText: 'اسم المستخدم',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ).animate().slideX(begin: 0.2, delay: 500.ms),
                      
                      const SizedBox(height: 20),
                      
                      // Password Input
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        onSubmitted: (_) {
                          if (!authCtrl.isLoading.value) {
                            authCtrl.login(usernameCtrl.text, passwordCtrl.text, context);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: true,
                          fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ).animate().slideX(begin: 0.2, delay: 600.ms),
                      
                      const SizedBox(height: 32),
                      
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: Obx(() => ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: authCtrl.isLoading.value
                              ? null
                              : () => authCtrl.login(usernameCtrl.text, passwordCtrl.text, context),
                          child: authCtrl.isLoading.value
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('دخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        )),
                      ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
                      
                      const SizedBox(height: 24),
                      Text('نسيت كلمة المرور؟ راجع الإدارة', style: TextStyle(color: Colors.grey[500], fontSize: 13)).animate().fadeIn(delay: 800.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
