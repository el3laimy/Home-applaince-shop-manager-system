import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/customer_model.dart';
import '../models/installment_model.dart';
import '../services/api_service.dart';
import '../core/utils/toast_service.dart';

// Model for a product in the checklist
class BridalChecklistItem {
  final String productId;
  final String productName;
  final String category;
  final double unitPrice;
  final int quantity;
  final double stockQuantity;

  BridalChecklistItem({
    required this.productId,
    required this.productName,
    required this.category,
    required this.unitPrice,
    required this.quantity,
    required this.stockQuantity,
  });

  bool get isAvailable => stockQuantity >= quantity;
}

class BridalController extends GetxController {
  // List of all bridal orders
  final RxList<Map<String, dynamic>> bridalOrders = <Map<String, dynamic>>[].obs;

  // Currently selected order detail
  final Rx<Map<String, dynamic>?> selectedOrder = Rx(null);
  final RxList<BridalChecklistItem> checklistItems = <BridalChecklistItem>[].obs;
  final RxList<InstallmentModel> installments = <InstallmentModel>[].obs;

  // Products for the category picker
  final RxList<Map<String, dynamic>> categoryProducts = <Map<String, dynamic>>[].obs;
  final RxBool loadingProducts = false.obs;

  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;

  // Reminders for approaching deliveries
  final RxList<Map<String, dynamic>> deliveryReminders = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingReminders = false.obs;

  // Computed totals for selected order
  double get totalAmount => checklistItems.fold(0, (s, i) => s + i.unitPrice * i.quantity);
  double get paidAmount => (selectedOrder.value?['paidAmount'] as num?)?.toDouble() ?? 0;
  double get remainingAmount => (selectedOrder.value?['remainingAmount'] as num?)?.toDouble() ?? 0;
  double get completionPct => totalAmount > 0 ? (paidAmount / totalAmount * 100).clamp(0, 100) : 0;

  // Default category list — user can add/remove
  final RxList<String> defaultCategories = <String>[
    'ثلاجة',
    'غسالة',
    'بوتاجاز',
    'شاشة',
    'مكيف',
    'غسالة صحون',
    'فريزر',
    'ميكروويف',
    'بوتاجاز',
    'ستيريو',
  ].obs;

  @override
  void onInit() {
    super.onInit();
    fetchOrders();
    fetchReminders();
  }

  Future<void> fetchOrders({String? search}) async {
    isLoading.value = true;
    try {
      final url = 'erp/bridal-orders${search != null && search.isNotEmpty ? '?search=${Uri.encodeComponent(search)}' : ''}';
      final data = await ApiService.get(url);
      bridalOrders.assignAll((data as List<dynamic>? ?? []).cast<Map<String, dynamic>>());
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> selectOrder(String orderId) async {
    isLoading.value = true;
    try {
      final data = await ApiService.get('erp/bridal-orders/$orderId');
      final m = data as Map<String, dynamic>;
      selectedOrder.value = m;

      // Map items to checklist
      final items = (m['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      checklistItems.assignAll(items.map((i) => BridalChecklistItem(
        productId: i['productId'] as String? ?? '',
        productName: i['productName'] as String? ?? '',
        category: '',
        unitPrice: (i['unitPrice'] as num?)?.toDouble() ?? 0,
        quantity: (i['quantity'] as num?)?.toInt() ?? 1,
        stockQuantity: (i['stockQuantity'] as num?)?.toDouble() ?? 0,
      )));
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadProductsByCategory(String category) async {
    loadingProducts.value = true;
    categoryProducts.clear();
    try {
      final data = await ApiService.get(
          'erp/bridal-orders/products-by-category?category=${Uri.encodeComponent(category)}');
      categoryProducts.assignAll((data as List<dynamic>? ?? []).cast<Map<String, dynamic>>());
    } catch (_) {
    } finally {
      loadingProducts.value = false;
    }
  }

  void addItemToChecklist(Map<String, dynamic> product, String category, int qty) {
    final existing = checklistItems.indexWhere((i) => i.productId == product['id']);
    if (existing >= 0) {
      // Update quantity
      final old = checklistItems[existing];
      checklistItems[existing] = BridalChecklistItem(
        productId: old.productId,
        productName: old.productName,
        category: old.category,
        unitPrice: old.unitPrice,
        quantity: qty,
        stockQuantity: old.stockQuantity,
      );
    } else {
      checklistItems.add(BridalChecklistItem(
        productId: product['id'] as String? ?? '',
        productName: product['name'] as String? ?? '',
        category: category,
        unitPrice: (product['price'] as num?)?.toDouble() ?? 0,
        quantity: qty,
        stockQuantity: (product['stockQuantity'] as num?)?.toDouble() ?? 0,
      ));
    }
    checklistItems.refresh();
  }

  void removeItem(String productId) {
    checklistItems.removeWhere((i) => i.productId == productId);
  }

  Future<bool> createOrder({
    required String customerId,
    required double downPayment,
    required DateTime? eventDate,
    required DateTime? deliveryDate,
    required String? notes,
  }) async {
    try {
      final items = checklistItems.map((i) => {
        'productId': i.productId,
        'quantity': i.quantity,
        'unitPrice': i.unitPrice,
      }).toList();

      final total = checklistItems.fold(0.0, (s, i) => s + i.unitPrice * i.quantity);
      await ApiService.post('erp/bridal-orders', {
        'customerId': customerId,
        'totalAmount': total,
        'downPayment': downPayment,
        'eventDate': eventDate?.toIso8601String(),
        'deliveryDate': deliveryDate?.toIso8601String(),
        'bridalNotes': notes,
        'items': items,
      });

      await fetchOrders();
      checklistItems.clear();
      ToastService.showSuccess('تم إنشاء حجز العروسة بنجاح');
      return true;
    } on ApiException catch (e) {
      ToastService.showError(e.message);
      return false;
    }
  }

  Future<bool> updateItems(String orderId) async {
    try {
      final items = checklistItems.map((i) => {
        'productId': i.productId,
        'quantity': i.quantity,
        'unitPrice': i.unitPrice,
      }).toList();
      await ApiService.patch('erp/bridal-orders/$orderId/items', items);
      await selectOrder(orderId);
      ToastService.showSuccess('تم تحديث قائمة الأجهزة');
      return true;
    } on ApiException catch (e) {
      ToastService.showError(e.message);
      return false;
    }
  }

  // Customers for the picker
  final RxList<Map<String, dynamic>> customerSuggestions = <Map<String, dynamic>>[].obs;

  Future<void> searchCustomers(String q) async {
    if (q.isEmpty) { customerSuggestions.clear(); return; }
    try {
      final data = await ApiService.get('customers?search=${Uri.encodeComponent(q)}&pageSize=10');
      customerSuggestions.assignAll(
        ((data['data'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> fetchReminders() async {
    isLoadingReminders.value = true;
    try {
      final data = await ApiService.get('erp/bridal-orders/reminders');
      deliveryReminders.assignAll((data as List<dynamic>? ?? []).cast<Map<String, dynamic>>());
    } catch (_) {
    } finally {
      isLoadingReminders.value = false;
    }
  }

  Future<bool> deliverOrder(String orderId) async {
    isLoading.value = true;
    try {
      final res = await ApiService.post('erp/bridal-orders/$orderId/deliver', {});
      ToastService.showSuccess((res as Map<String, dynamic>)['message']?.toString() ?? 'تم تسليم الطلب بنجاح');
      await fetchOrders();
      await fetchReminders();
      await selectOrder(orderId); // Refresh selected order status
      return true;
    } on ApiException catch (e) {
      ToastService.showError(e.message);
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
