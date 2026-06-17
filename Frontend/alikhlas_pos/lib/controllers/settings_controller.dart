import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import '../core/utils/snackbar_helper.dart';

class SettingsController extends GetxController {
  final RxBool isLoading = true.obs;
  
  // Printer config
  final RxString selectedPrinter = 'Default Printer'.obs; // Legacy, will keep for compatibility for now
  final RxString receiptPrinterName = 'Default'.obs;
  final RxString labelPrinterName = 'Default'.obs;
  final RxList<String> availablePrinters = <String>['Default'].obs;
  
  final RxBool autoPrintReceipts = true.obs;
  final RxBool printInvoiceBarcode = true.obs;

  // App behaviors
  final RxBool enableKeyboardShortcuts = true.obs;
  final RxString posThemeColor = 'Blue'.obs; // Blue, Green, Red
  
  @override
  void onInit() {
    super.onInit();
    loadSettings();
    refreshPrinterList();
  }

  Future<void> refreshPrinterList() async {
    try {
      final printers = await Printing.listPrinters();
      availablePrinters.assignAll(['Default', ...printers.map((p) => p.name)]);
    } catch (_) {
      availablePrinters.assignAll(['Default']);
    }
  }

  Future<void> loadSettings() async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      selectedPrinter.value = prefs.getString('printer_name') ?? 'Default Printer';
      receiptPrinterName.value = prefs.getString('receipt_printer') ?? 'Default';
      labelPrinterName.value = prefs.getString('label_printer') ?? 'Default';
      
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
      await prefs.setString('receipt_printer', receiptPrinterName.value);
      await prefs.setString('label_printer', labelPrinterName.value);
      
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
