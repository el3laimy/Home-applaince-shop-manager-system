import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/supplier_model.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../core/utils/toast_service.dart';

class PurchaseItemRow {
  String productId;
  String productName;
  double quantity;
  double unitCost;

  PurchaseItemRow({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
  });

  double get total => quantity * unitCost;
}

class PurchasingController extends GetxController {
  // ----------------
  // Tab 1: New Invoice (Refactored for speed)
  // ----------------
  final Rx<SupplierModel?> selectedSupplier = Rx<SupplierModel?>(null);
  // Using an observable list of typed objects for inline editing
  final RxList<PurchaseItemRow> purchaseItems = <PurchaseItemRow>[].obs;
  final RxString referenceNumber = ''.obs;
  
  // Product search
  final RxList<ProductModel> searchResults = <ProductModel>[].obs;
  final RxBool isSearchingProducts = false.obs;
  
  // Safe balance
  final RxDouble safeBalance = 0.0.obs;

  double get invoiceTotal => purchaseItems.fold(0, (sum, item) => sum + item.total);

  // ----------------
  // Suppliers & History
  // ----------------
  final RxList<SupplierModel> suppliersWithBalances = <SupplierModel>[].obs;
  final RxBool isLoadingSuppliers = false.obs;

  final RxList<Map<String, dynamic>> allInvoices = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingInvoices = false.obs;

  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchSuppliersWithBalances();
    fetchSafeBalance();
    fetchAllInvoices();
  }

  Future<void> fetchSafeBalance() async {
    try {
      final res = await ApiService.get('erp/finance/safe-balance');
      safeBalance.value = (res['safeBalance'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}
  }

  Future<void> fetchSuppliersWithBalances({String? search}) async {
    isLoadingSuppliers.value = true;
    try {
      final endpoint = 'erp/suppliers${search != null && search.isNotEmpty ? "?search=${Uri.encodeComponent(search)}" : ""}';
      final data = await ApiService.getList(endpoint);
      suppliersWithBalances.assignAll(data.map((e) => SupplierModel.fromJson(e as Map<String, dynamic>)).toList());
    } catch (e) {
       print('Error in fetchSuppliersWithBalances: $e');
    } finally {
      isLoadingSuppliers.value = false;
    }
  }

  Future<void> searchProducts(String query) async {
    if (query.trim().isEmpty) {
      searchResults.clear();
      return;
    }
    isSearchingProducts.value = true;
    try {
      // Changed to support barcode scanner instantly
      final isLikelyBarcode = RegExp(r'^[0-9]+$').hasMatch(query) && query.length > 5;
      final endpoint = isLikelyBarcode ? 'products/barcode/$query' : 'products?search=${Uri.encodeComponent(query)}&pageSize=15';
      
      final data = await ApiService.get(endpoint);
      
      if (isLikelyBarcode && data is Map<String, dynamic> && data.containsKey('id')) {
          // Direct barcode hit
          final p = ProductModel.fromJson(data);
          addItemToInvoice(p, 1.0, p.purchasePrice);
          searchResults.clear();
          ToastService.showSuccess('تمت إضافة ${p.name}');
      } else {
          final list = (data['data'] as List<dynamic>? ?? [])
              .map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
              .toList();
          searchResults.assignAll(list);
          
          // Auto add if exactly 1 result and it's a barcode scan
          if (isLikelyBarcode && list.length == 1) {
             addItemToInvoice(list.first, 1.0, list.first.purchasePrice);
             searchResults.clear();
          }
      }
    } catch (_) {
      searchResults.clear();
    } finally {
      isSearchingProducts.value = false;
    }
  }

  // ==== Invoice Local State Management ====

  void selectSupplierById(String id) {
     final target = suppliersWithBalances.firstWhereOrNull((s) => s.id == id);
     if (target != null) {
        selectedSupplier.value = target;
     } else {
        selectedSupplier.value = null;
     }
  }

  // ZERO-CLICK ADD: Directly adds to list
  void addItemToInvoice(ProductModel product, double quantity, double unitCost) {
    final existingIndex = purchaseItems.indexWhere((i) => i.productId == product.id);
    if (existingIndex != -1) {
      // Update existing
      purchaseItems[existingIndex].quantity += quantity;
      purchaseItems[existingIndex].unitCost = unitCost; // Update to latest cost
      purchaseItems.refresh(); // force UI update
    } else {
      // Add new
      purchaseItems.add(PurchaseItemRow(
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        unitCost: unitCost,
      ));
    }
  }

  void updateItemQuantity(int index, double newQuantity) {
     if (newQuantity <= 0) return removeItem(index);
     purchaseItems[index].quantity = newQuantity;
     purchaseItems.refresh();
  }
  
  void updateItemCost(int index, double newCost) {
     if (newCost < 0) return;
     purchaseItems[index].unitCost = newCost;
     purchaseItems.refresh();
  }

  void removeItem(int index) => purchaseItems.removeAt(index);

  Future<bool> createNewProductForInvoice(Map<String, dynamic> data, BuildContext context) async {
    isLoading.value = true;
    try {
       final res = await ApiService.post('products', data);
       if (res != null && res['id'] != null) {
          final p = ProductModel.fromJson(res as Map<String, dynamic>);
          addItemToInvoice(p, 1.0, data['purchasePrice'] as double);
          ToastService.showSuccess('تم إضافة الصنف الجديد بنجاح للفاتورة');
          return true;
       }
       return false;
    } on ApiException catch (e) {
       ToastService.showError(e.message);
       return false;
    } finally {
       isLoading.value = false;
    }
  }

  Future<bool> submitInvoice(double paidAmount, BuildContext context, {String status = 'Completed'}) async {
    if (selectedSupplier.value == null || purchaseItems.isEmpty) {
      ToastService.showWarning('يرجى اختيار مورد وإضافة أصناف');
      return false;
    }
    isLoading.value = true;
    try {
      await ApiService.post('erp/purchases', {
        'supplierId': selectedSupplier.value!.id,
        'referenceNumber': referenceNumber.value.isEmpty ? null : referenceNumber.value,
        'paidAmount': paidAmount,
        'status': status,
        'items': purchaseItems.map((i) => {
          'productId': i.productId,
          'quantity': i.quantity,
          'unitCost': i.unitCost,
        }).toList(),
      });
      purchaseItems.clear();
      selectedSupplier.value = null;
      referenceNumber.value = '';
      ToastService.showSuccess(status == 'Draft' ? 'تم حفظ الفاتورة كمسودة' : 'تم ترحيل الفاتورة بنجاح');
      await fetchSuppliersWithBalances();
      await fetchSafeBalance();
      await fetchAllInvoices();
      return true;
    } on ApiException catch (e) {
      ToastService.showError(e.message);
      return false;
    } finally {
      isLoading.value = false;
    }
  }
  
  // Stubs for remaining functions to avoid breaking SuppliersScreen for now
  Future<String?> addSupplier(Map<String, dynamic> data, BuildContext context) async {
    isLoading.value = true;
    try {
       final res = await ApiService.post('erp/suppliers', data);
       await fetchSuppliersWithBalances();
       ToastService.showSuccess('تم إضافة المورد بنجاح');
       return res['id'] as String?;
    } on ApiException catch (e) {
       ToastService.showError(e.message);
       return null;
    } finally {
       isLoading.value = false;
    }
  }

  Future<bool> updateSupplier(String id, Map<String, dynamic> data, BuildContext context) async {
    isLoading.value = true;
    try {
       await ApiService.put('erp/suppliers/$id', data);
       await fetchSuppliersWithBalances();
       ToastService.showSuccess('تم تعديل المورد بنجاح');
       return true;
    } on ApiException catch (e) {
       ToastService.showError(e.message);
       return false;
    } finally {
       isLoading.value = false;
    }
  }

  Future<bool> deleteSupplier(String id, BuildContext context) async {
    isLoading.value = true;
    try {
       await ApiService.delete('erp/suppliers/$id');
       await fetchSuppliersWithBalances();
       ToastService.showWarning('تم حذف المورد بنجاح');
       return true;
    } on ApiException catch (e) {
       ToastService.showError(e.message);
       return false;
    } finally {
       isLoading.value = false;
    }
  }

  Future<bool> registerSupplierPayment(String supplierId, double amount, String notes, BuildContext context) async {
    isLoading.value = true;
    try {
      await ApiService.post('erp/suppliers/$supplierId/payment', {
        'amount': amount,
        'notes': notes,
      });
      await fetchSuppliersWithBalances();
      ToastService.showSuccess('تم تسجيل الدفعة بنجاح');
      return true;
    } on ApiException catch (e) {
      ToastService.showError(e.message);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchAllInvoices() async {
     isLoadingInvoices.value = true;
     try {
       final data = await ApiService.getList('erp/purchases');
       allInvoices.assignAll(data.cast<Map<String, dynamic>>());
     } catch (_) {
     } finally {
       isLoadingInvoices.value = false;
     }
  }
}
