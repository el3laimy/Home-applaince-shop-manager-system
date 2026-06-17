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

  // Date filter (Task 3.1)
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    fetchFinanceSummary();
  }

  Future<void> fetchFinanceSummary() async {
    isLoading.value = true;
    try {
      final dateStr = '${selectedDate.value.year}-${selectedDate.value.month.toString().padLeft(2, '0')}-${selectedDate.value.day.toString().padLeft(2, '0')}';
      final data = await ApiService.get('erp/finance/summary?date=$dateStr');
      cashDrawerBalance.value = (data['cashDrawerBalance'] as num? ?? 0).toDouble();
      mainTreasuryBalance.value = (data['mainTreasuryBalance'] as num? ?? 0).toDouble();
      todayExpenses.value = (data['todayExpenses'] as num? ?? 0).toDouble();
      todaySales.value = (data['todaySales'] as num? ?? 0).toDouble();

      final transactions = await ApiService.get('erp/finance/cash-transactions?period=today&date=$dateStr');
      cashTransactions.assignAll(
        (transactions['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>()
      );
    } catch (_) {} finally {
      isLoading.value = false;
    }
  }

  Future<bool> recordExpense(Map<String, dynamic> expenseData) async {
    isLoading.value = true;
    try {
      await ApiService.post('erp/finance/expenses', expenseData);
      await fetchFinanceSummary();
      ToastService.showSuccess('تم تسجيل المصروف بنجاح');
      return true;
    } on ApiException catch (e) {
      ToastService.showError(e.message);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> closePeriod() async {
    isLoading.value = true;
    try {
      final data = await ApiService.post('erp/finance/close-period', {});
      ToastService.showSuccess('تم إقفال الفترة. صافي الربح: ${data['netProfit']} ج.م');
      await fetchFinanceSummary();
      return true;
    } on ApiException catch (e) {
      ToastService.showError(e.message);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> transferToTreasury(double amount, String description) async {
    isLoading.value = true;
    try {
      await ApiService.post('erp/finance/transfer-to-treasury', {
        'amount': amount,
        'description': description
      });
      ToastService.showSuccess('تم توريد النقدية بنجاح');
      await fetchFinanceSummary();
      return true;
    } on ApiException catch (e) {
      ToastService.showError(e.message);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

}
