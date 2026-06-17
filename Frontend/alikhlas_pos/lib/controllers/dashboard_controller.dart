import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:signalr_netcore/signalr_client.dart';
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
  
  // Detailed Alerts Lists
  var lowStockDetails = [].obs;
  var overdueDetails = [].obs;

  // SignalR Connection
  HubConnection? _hubConnection;

  @override
  void onInit() {
    super.onInit();
    fetchSummary();
    _initSignalR();
  }

  @override
  void onClose() {
    _hubConnection?.stop();
    super.onClose();
  }

  void _initSignalR() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:5291/api';
    // Remove trailing slash if any, then remove /api
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    String hubUrl = baseUrl.replaceAll(RegExp(r'/api$'), '/hubs/dashboard');
    
    _hubConnection = HubConnectionBuilder()
        .withUrl(hubUrl)
        .withAutomaticReconnect()
        .build();

    _hubConnection?.on('UpdateDashboard', (arguments) {
      // Re-fetch dashboard when a relevant backend event occurs
      fetchSummary();
    });

    _startSignalR();
  }

  Future<void> _startSignalR() async {
    try {
      if (_hubConnection?.state == HubConnectionState.Disconnected) {
        await _hubConnection?.start();
        print("SignalR Connected to Dashboard Hub");
      }
    } catch (e) {
      print("SignalR Connection Error: $e");
    }
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
      // Task 2.3: Fill missing dates to ensure chart is always safe
      final rawTrend = (data['salesTrend'] as List? ?? []).cast<Map<String, dynamic>>();
      salesTrend.assignAll(_fillMissingDates(rawTrend));

      // Fetch detailed alert lists
      try {
        final lowStockRes = await ApiService.get('dashboard/low-stock?threshold=5');
        if (lowStockRes != null && lowStockRes is List) {
          lowStockDetails.assignAll(lowStockRes);
        }
      } catch (_) {}

      try {
        final overdueRes = await ApiService.get('dashboard/overdue-installments');
        if (overdueRes != null && overdueRes is List) {
          overdueDetails.assignAll(overdueRes);
        }
      } catch (_) {}

    } catch (e) {
      errorMessage.value = 'فشل تحميل الإحصائيات: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Task 2.3: Ensures salesTrend always has consecutive dates (last 7 days)
  /// by filling missing dates with zero values.
  List<Map<String, dynamic>> _fillMissingDates(List<Map<String, dynamic>> rawData) {
    const days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final result = <Map<String, dynamic>>[];
    final now = DateTime.now();

    // Build a lookup map from date string → data point
    final Map<String, Map<String, dynamic>> lookup = {};
    for (final item in rawData) {
      final dateStr = item['date']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        // Normalize to yyyy-MM-dd
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          final key = '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
          lookup[key] = item;
        }
      }
    }

    // Generate the last 7 days
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (lookup.containsKey(key)) {
        result.add(lookup[key]!);
      } else {
        result.add({
          'date': key,
          'dayName': days[day.weekday % 7],
          'total': 0,
          'profit': 0,
        });
      }
    }

    return result;
  }
}


