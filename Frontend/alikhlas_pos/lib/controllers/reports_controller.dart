import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';

class ReportsController extends GetxController {
  final RxBool isLoading = false.obs;
  
  // Date Range
  final Rx<DateTime> startDate = DateTime.now().subtract(const Duration(days: 30)).obs;
  final Rx<DateTime> endDate = DateTime.now().obs;

  // Sales Data
  final RxMap<String, dynamic> salesMetrics = <String, dynamic>{}.obs;
  final RxList<dynamic> salesTrend = <dynamic>[].obs;

  // Inventory Data
  final RxMap<String, dynamic> inventoryMetrics = <String, dynamic>{}.obs;
  final RxList<dynamic> valueByCategory = <dynamic>[].obs;

  // Top Products Data
  final RxList<dynamic> topProducts = <dynamic>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchAllReports();
  }

  void updateDateRange(DateTime start, DateTime end) {
    startDate.value = start;
    endDate.value = end;
    fetchSalesReport(); // Only sales report depends on date
  }

  Future<void> fetchAllReports() async {
    isLoading.value = true;
    try {
      await Future.wait([
        fetchSalesReport(showLoading: false),
        fetchInventoryReport(showLoading: false),
        fetchTopProducts(showLoading: false),
      ]);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل التقارير', backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchSalesReport({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    try {
      final sd = startDate.value.toIso8601String().split('T')[0];
      final ed = endDate.value.add(const Duration(days: 1)).toIso8601String().split('T')[0]; // Include full end day
      
      final data = await ApiService.get('reports/sales?startDate=$sd&endDate=$ed');
      salesMetrics.value = data['metrics'] as Map<String, dynamic>;
      salesTrend.assignAll(data['salesTrend'] as List<dynamic>);
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  Future<void> fetchInventoryReport({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    try {
      final data = await ApiService.get('reports/inventory-value');
      inventoryMetrics.value = {
        'TotalCostValue': data['totalCostValue'],
        'TotalRetailValue': data['totalRetailValue'],
        'ExpectedProfit': data['expectedProfit'],
      };
      valueByCategory.assignAll(data['valueByCategory'] as List<dynamic>);
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  Future<void> fetchTopProducts({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    try {
      final data = await ApiService.getList('reports/top-products?limit=10');
      topProducts.assignAll(data);
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }
}
