import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../core/utils/toast_service.dart';

class FinanceController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxDouble cashDrawerBalance = 0.0.obs;
  final RxDouble mainTreasuryBalance = 0.0.obs;
  final RxDouble todayExpenses = 0.0.obs;
  final RxDouble todaySales = 0.0.obs;
  final RxList<Map<String, dynamic>> cashTransactions = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchFinanceSummary();
  }

  Future<void> fetchFinanceSummary() async {
    isLoading.value = true;
    try {
      final data = await ApiService.get('erp/finance/summary');
      cashDrawerBalance.value = (data['cashDrawerBalance'] as num? ?? 0).toDouble();
      mainTreasuryBalance.value = (data['mainTreasuryBalance'] as num? ?? 0).toDouble();
      todayExpenses.value = (data['todayExpenses'] as num? ?? 0).toDouble();
      todaySales.value = (data['todaySales'] as num? ?? 0).toDouble();

      final transactions = await ApiService.get('erp/finance/cash-transactions?period=today');
      cashTransactions.assignAll(
        (transactions['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>()
      );
    } catch (_) {} finally {
      isLoading.value = false;
    }
  }

  Future<bool> recordExpense(Map<String, dynamic> expenseData, BuildContext context) async {
    isLoading.value = true;
    try {
      await ApiService.post('erp/finance/expenses', expenseData);
      await fetchFinanceSummary();
      _snap(context, 'تم تسجيل المصروف بنجاح', Colors.green);
      return true;
    } on ApiException catch (e) {
      _snap(context, e.message, Colors.red);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> closePeriod(BuildContext context) async {
    isLoading.value = true;
    try {
      final data = await ApiService.post('erp/finance/close-period', {});
      _snap(context, 'تم إقفال الفترة. صافي الربح: ${data['netProfit']} ج.م', Colors.green);
      await fetchFinanceSummary();
      return true;
    } on ApiException catch (e) {
      _snap(context, e.message, Colors.red);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> transferToTreasury(double amount, String description, BuildContext context) async {
    isLoading.value = true;
    try {
      await ApiService.post('erp/finance/transfer-to-treasury', {
        'amount': amount,
        'description': description
      });
      _snap(context, 'تم توريد النقدية بنجاح', Colors.green);
      await fetchFinanceSummary();
      return true;
    } on ApiException catch (e) {
      _snap(context, e.message, Colors.red);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  void _snap(BuildContext $1, String msg, Color color) {
    if (color == Colors.red || color == Colors.redAccent) { ToastService.showError(msg); }
    else if (color == Colors.green || color == Colors.greenAccent) { ToastService.showSuccess(msg); }
    else if (color == Colors.orange || color == Colors.orangeAccent) { ToastService.showWarning(msg); }
    else { ToastService.showInfo(msg); }
  }

}
