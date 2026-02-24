import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/snackbar_helper.dart';

class SettingsController extends GetxController {
  final RxBool isLoading = true.obs;
  
  // Printer config
  final RxString selectedPrinter = 'Default Printer'.obs;
  final RxBool autoPrintReceipts = true.obs;
  final RxBool printInvoiceBarcode = true.obs;

  // App behaviors
  final RxBool enableKeyboardShortcuts = true.obs;
  final RxString posThemeColor = 'Blue'.obs; // Blue, Green, Red
  
  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  Future<void> loadSettings() async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      selectedPrinter.value = prefs.getString('printer_name') ?? 'Default Printer';
      autoPrintReceipts.value = prefs.getBool('auto_print') ?? true;
      printInvoiceBarcode.value = prefs.getBool('print_barcode') ?? true;
      
      enableKeyboardShortcuts.value = prefs.getBool('enable_shortcuts') ?? true;
      posThemeColor.value = prefs.getString('pos_theme') ?? 'Blue';
    } catch (_) {
      SnackbarHelper.showError(message: 'فشل تحميل الإعدادات');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveSettings() async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('printer_name', selectedPrinter.value);
      await prefs.setBool('auto_print', autoPrintReceipts.value);
      await prefs.setBool('print_barcode', printInvoiceBarcode.value);
      
      await prefs.setBool('enable_shortcuts', enableKeyboardShortcuts.value);
      await prefs.setString('pos_theme', posThemeColor.value);
      
      SnackbarHelper.showSuccess(message: 'تم حفظ الإعدادات بنجاح');
    } catch (_) {
      SnackbarHelper.showError(message: 'فشل حفظ الإعدادات');
    } finally {
      isLoading.value = false;
    }
  }
}
