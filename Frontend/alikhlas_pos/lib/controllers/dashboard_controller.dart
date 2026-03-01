import 'package:get/get.dart';
import '../services/api_service.dart';

class DashboardController extends GetxController {
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  // Key Metrics
  var todaySales = 0.0.obs;
  var dailySalesGrowth = 0.0.obs; // NEW
  var dailyInvoicesCount = 0.obs;
  
  var monthlySales = 0.0.obs;
  var monthlySalesGrowth = 0.0.obs;
  
  var monthlyGrossProfit = 0.0.obs; // NEW
  var monthlyNetProfit = 0.0.obs;
  var grossMargin = 0.0.obs; // NEW
  var netMargin = 0.0.obs; // NEW
  var expenseRatio = 0.0.obs; // NEW

  // Entities Stats
  var totalProducts = 0.obs;
  var lowStockProducts = 0.obs;
  var totalCustomers = 0.obs;

  // Alerts
  var overdueInstallmentsCount = 0.obs;
  var overdueInstallmentsTotal = 0.0.obs;
  var dueSoonCount = 0.obs;

  // Lists
  var recentInvoices = [].obs;
  var topProfitableProducts = [].obs; // NEW
  var salesTrend = [].obs; // Now contains {date, dayName, total, profit}

  @override
  void onInit() {
    super.onInit();
    fetchSummary();
  }

  Future<void> fetchSummary() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      final data = await ApiService.get('dashboard/summary');
      
      // Batch updates if possible or update one by one but in a controlled manner
      todaySales.value = (data['todaySales'] as num?)?.toDouble() ?? 0.0;
      dailySalesGrowth.value = (data['dailySalesGrowth'] as num?)?.toDouble() ?? 0.0;
      dailyInvoicesCount.value = (data['dailyInvoicesCount'] as num?)?.toInt() ?? 0;
      
      monthlySales.value = (data['monthlySales'] as num?)?.toDouble() ?? 0.0;
      monthlySalesGrowth.value = (data['monthlySalesGrowth'] as num?)?.toDouble() ?? 0.0;
      
      monthlyGrossProfit.value = (data['monthlyGrossProfit'] as num?)?.toDouble() ?? 0.0;
      monthlyNetProfit.value = (data['monthlyNetProfit'] as num?)?.toDouble() ?? 0.0;
      grossMargin.value = (data['grossMargin'] as num?)?.toDouble() ?? 0.0;
      netMargin.value = (data['netMargin'] as num?)?.toDouble() ?? 0.0;
      expenseRatio.value = (data['expenseRatio'] as num?)?.toDouble() ?? 0.0;

      totalProducts.value = (data['totalProducts'] as num?)?.toInt() ?? 0;
      lowStockProducts.value = (data['lowStockProducts'] as num?)?.toInt() ?? 0;
      totalCustomers.value = (data['totalCustomers'] as num?)?.toInt() ?? 0;

      overdueInstallmentsCount.value = (data['overdueInstallmentsCount'] as num?)?.toInt() ?? 0;
      overdueInstallmentsTotal.value = (data['overdueInstallmentsTotal'] as num?)?.toDouble() ?? 0.0;
      dueSoonCount.value = (data['dueSoonCount'] as num?)?.toInt() ?? 0;

      recentInvoices.assignAll(data['recentInvoices'] ?? []);
      topProfitableProducts.assignAll(data['topProfitableProducts'] ?? []);
      salesTrend.assignAll(data['salesTrend'] ?? []);

    } catch (e) {
      errorMessage.value = 'فشل تحميل الإحصائيات: $e';
    } finally {
      isLoading.value = false;
    }
  }
}

