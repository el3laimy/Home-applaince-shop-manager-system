import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/customer_model.dart';
import '../services/api_service.dart';
import '../core/utils/toast_service.dart';

class CustomerController extends GetxController {
  final RxList<CustomerModel> customers = <CustomerModel>[].obs;
  final Rx<CustomerModel?> selected = Rx<CustomerModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxList<Map<String, dynamic>> statement = <Map<String, dynamic>>[].obs;
  final RxDouble totalDue = 0.0.obs;
  final RxDouble totalPaid = 0.0.obs;
  final RxDouble totalReturns = 0.0.obs;
  final RxDouble remainingBalance = 0.0.obs;

  // Pagination state
  final RxInt _page = 1.obs;
  final RxInt totalCount = 0.obs;
  static const int _pageSize = 30;
  String? _lastSearch;

  // Sort
  final RxString sortBy = 'name'.obs;

  bool get hasMore => customers.length < totalCount.value;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  /// Fetches the first page. Pass [search] to filter.
  Future<void> fetch({String? search}) async {
    _page.value = 1;
    _lastSearch = search;
    isLoading.value = true;
    try {
      final url = _buildUrl(1, search);
      final data = await ApiService.get(url);
      totalCount.value = (data['total'] as num? ?? 0).toInt();
      customers.assignAll(
        (data['data'] as List<dynamic>? ?? [])
            .map((c) => CustomerModel.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  /// Loads the next page and appends to customers list.
  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore.value || isLoading.value) return;
    isLoadingMore.value = true;
    _page.value++;
    try {
      final url = _buildUrl(_page.value, _lastSearch);
      final data = await ApiService.get(url);
      final newItems = (data['data'] as List<dynamic>? ?? [])
          .map((c) => CustomerModel.fromJson(c as Map<String, dynamic>))
          .toList();
      customers.addAll(newItems);
    } catch (_) {
      _page.value--; // revert on failure
    } finally {
      isLoadingMore.value = false;
    }
  }

  String _buildUrl(int page, String? search) {
    String url = 'customers?page=$page&pageSize=$_pageSize&sortBy=${sortBy.value}';
    if (search != null && search.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(search)}';
    }
    return url;
  }

  void changeSort(String newSort) {
    sortBy.value = newSort;
    fetch(search: _lastSearch);
  }

  Future<void> selectCustomer(CustomerModel c) async {
    selected.value = c;
    isLoading.value = true;
    try {
      final data = await ApiService.get('customers/${c.id}/statement');
      final customerData = data['customer'] as Map<String, dynamic>? ?? {};
      totalDue.value = (customerData['totalPurchases'] as num? ?? 0).toDouble();
      totalPaid.value = (customerData['totalPaid'] as num? ?? 0).toDouble();
      totalReturns.value = (customerData['totalReturns'] as num? ?? 0).toDouble();
      remainingBalance.value = (customerData['remainingBalance'] as num? ?? 0).toDouble();
      
      statement.assignAll(
          (data['timeline'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>());
      debugPrint('Loaded ${statement.length} items for timeline');
    } catch (e) {
      debugPrint('❌ selectCustomer error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addCustomer(String name, String? phone, String? address, String? notes, BuildContext ctx) async {
    try {
      await ApiService.post('customers', {
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
      });
      await fetch();
      ToastService.showSuccess('تم إضافة العميل بنجاح');
      return true;
    } on ApiException catch (e) {
      ToastService.showError(e.message);
      return false;
    }
  }

  Future<bool> updateCustomer(String id, String name, String? phone, String? address, String? notes) async {
    try {
      await ApiService.put('customers/$id', {
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
      });
      // Update local data
      final idx = customers.indexWhere((c) => c.id == id);
      if (idx >= 0) {
        await fetch(search: _lastSearch);
      }
      if (selected.value?.id == id) {
        // Refresh the selected customer
        final updatedList = customers.where((c) => c.id == id);
        if (updatedList.isNotEmpty) {
          await selectCustomer(updatedList.first);
        }
      }
      ToastService.showSuccess('تم تعديل بيانات العميل');
      return true;
    } on ApiException catch (e) {
      ToastService.showError(e.message);
      return false;
    }
  }

  Future<bool> registerPayment(String customerId, double amount, String? note) async {
    try {
      await ApiService.post('customers/$customerId/payment', {
        'amount': amount,
        'note': note,
      });
      ToastService.showSuccess('تم تسجيل الدفعة بنجاح');
      // Refresh customer list and statement
      await fetch(search: _lastSearch);
      final updatedCustomer = customers.firstWhereOrNull((c) => c.id == customerId);
      if (updatedCustomer != null) {
        await selectCustomer(updatedCustomer);
      }
      return true;
    } on ApiException catch (e) {
      ToastService.showError(e.message);
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchInvoiceDetail(String customerId, String invoiceId) async {
    try {
      final data = await ApiService.get('customers/$customerId/invoices/$invoiceId');
      return data as Map<String, dynamic>;
    } catch (_) {
      ToastService.showError('خطأ في تحميل تفاصيل الفاتورة');
      return null;
    }
  }

  Future<bool> deleteCustomer(String id, BuildContext ctx) async {
    try {
      await ApiService.delete('customers/$id');
      customers.removeWhere((c) => c.id == id);
      totalCount.value = (totalCount.value - 1).clamp(0, double.maxFinite).toInt();
      if (selected.value?.id == id) selected.value = null;
      ToastService.showWarning('تم حذف العميل');
      return true;
    } on ApiException catch (e) {
      ToastService.showError(e.message);
      return false;
    }
  }
}
