import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the app-wide theme mode with persistence across sessions.
class ThemeController extends GetxController {
  static const _key = 'themeMode';

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    _loadFromPrefs();
  }

  /// Cycle: System → Light → Dark → System
  void cycle() {
    switch (themeMode.value) {
      case ThemeMode.system:
        setTheme(ThemeMode.light);
        break;
      case ThemeMode.light:
        setTheme(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setTheme(ThemeMode.system);
        break;
    }
  }

  void setTheme(ThemeMode mode) {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    _saveToPrefs(mode);
  }

  IconData get icon => switch (themeMode.value) {
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
        _ => Icons.brightness_auto_rounded,
      };

  String get label => switch (themeMode.value) {
        ThemeMode.light => 'فاتح',
        ThemeMode.dark => 'داكن',
        _ => 'تلقائي',
      };

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_key);
    if (saved != null) {
      final mode = ThemeMode.values[saved.clamp(0, ThemeMode.values.length - 1)];
      setTheme(mode);
    }
  }

  Future<void> _saveToPrefs(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }
}
