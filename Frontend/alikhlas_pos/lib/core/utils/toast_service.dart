import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class ToastService {
  static void showSuccess(String message, {String? title}) {
    toastification.show(
      type: ToastificationType.success,
      style: ToastificationStyle.flat,
      title: title != null ? Text(title) : const Text('نجاح'),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
      showProgressBar: false,
      margin: const EdgeInsets.only(top: 20, right: 20),
    );
  }

  static void showError(String message, {String? title}) {
    toastification.show(
      type: ToastificationType.error,
      style: ToastificationStyle.flat,
      title: title != null ? Text(title) : const Text('خطأ'),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 4),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      icon: const Icon(Icons.error_outline, color: Colors.red),
      showProgressBar: false,
      margin: const EdgeInsets.only(top: 20, right: 20),
    );
  }

  static void showWarning(String message, {String? title}) {
    toastification.show(
      type: ToastificationType.warning,
      style: ToastificationStyle.flat,
      title: title != null ? Text(title) : const Text('تنبيه'),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 4),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
      showProgressBar: false,
      margin: const EdgeInsets.only(top: 20, right: 20),
    );
  }

  static void showInfo(String message, {String? title}) {
    toastification.show(
      type: ToastificationType.info,
      style: ToastificationStyle.flat,
      title: title != null ? Text(title) : const Text('معلومة'),
      description: Text(message),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      icon: const Icon(Icons.info_outline, color: Colors.blue),
      showProgressBar: false,
      margin: const EdgeInsets.only(top: 20, right: 20),
    );
  }
}
