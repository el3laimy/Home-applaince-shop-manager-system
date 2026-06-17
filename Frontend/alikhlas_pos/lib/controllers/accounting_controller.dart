import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../services/accounting_api_service.dart';

class AccountingController extends GetxController {
  var currentTab = 0.obs;
  var isLoading = false.obs;

  // Chart of Accounts
  var chartOfAccounts = <dynamic>[].obs;

  // Reports Data
  var trialBalanceData = <String, dynamic>{}.obs;
  var incomeStatementData = <String, dynamic>{}.obs;
  var balanceSheetData = <String, dynamic>{}.obs;

  // Date Filters
  var selectedFromDate = Rxn<DateTime>(DateTime(DateTime.now().year, DateTime.now().month, 1)); // First of current month
  var selectedToDate = Rxn<DateTime>(DateTime.now());

  @override
  void onInit() {
    super.onInit();
    // Initially load COA
    loadChartOfAccounts();
  }

  void switchTab(int index) {
    currentTab.value = index;
    if (index == 1 && chartOfAccounts.isEmpty) {
      loadChartOfAccounts();
    } else if (index == 3) {
      // Auto-load reports if empty
      if (trialBalanceData.isEmpty) loadTrialBalance();
      if (incomeStatementData.isEmpty) loadIncomeStatement();
      if (balanceSheetData.isEmpty) loadBalanceSheet();
    }
  }

  Future<void> loadChartOfAccounts() async {
    try {
      isLoading.value = true;
      final data = await AccountingApiService.getChartOfAccounts();
      chartOfAccounts.value = data;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحميل شجرة الحسابات', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadTrialBalance() async {
    try {
      isLoading.value = true;
      final data = await AccountingApiService.getTrialBalance(from: selectedFromDate.value, to: selectedToDate.value);
      trialBalanceData.value = data;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل ميزان المراجعة', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadIncomeStatement() async {
    try {
      isLoading.value = true;
      final data = await AccountingApiService.getIncomeStatement(from: selectedFromDate.value, to: selectedToDate.value);
      incomeStatementData.value = data;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل قائمة الدخل', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadBalanceSheet() async {
    try {
      isLoading.value = true;
      final data = await AccountingApiService.getBalanceSheet(asOf: selectedToDate.value);
      balanceSheetData.value = data;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل الميزانية العمومية', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshReports() async {
    await loadTrialBalance();
    await loadIncomeStatement();
    await loadBalanceSheet();
  }

  Future<bool> submitManualJournal(String description, String? reference, List<Map<String, dynamic>> lines) async {
    try {
      isLoading.value = true;
      final success = await AccountingApiService.createManualJournalEntry(description, reference, lines);
      if (success) {
        Get.snackbar('نجاح', 'تم تسجيل القيد بنجاح', backgroundColor: Colors.green, colorText: Colors.white);
        return true;
      }
      return false;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تسجيل القيد', backgroundColor: Colors.redAccent, colorText: Colors.white);
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
