import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SnackbarHelper {
  static void showSuccess({required String message, String title = 'نجاح'}) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.green.withAlpha(230),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }

  static void showError({required String message, String title = 'خطأ'}) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.redAccent.withAlpha(230),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.error_outline, color: Colors.white),
    );
  }

  static void showWarning({required String message, String title = 'تنبيه'}) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.orange.withAlpha(230),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
    );
  }
}
