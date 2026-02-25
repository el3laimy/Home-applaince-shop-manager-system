import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/product_model.dart';
import '../models/invoice_model.dart';
import '../services/api_service.dart';
import '../services/receipt_service.dart';
import '../core/utils/toast_service.dart';

class PosController extends GetxController {
  // Cart state
  final RxList<CartItemModel> cartItems = <CartItemModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString lastScannedProductInfo = ''.obs;
  final Rx<ProductModel?> lastScannedProduct = Rx<ProductModel?>(null);

  // Quick Access Products (right panel)
  final RxList<ProductModel> quickAccessProducts = <ProductModel>[].obs;
  final RxList<String> categories = <String>[]
      .obs; // populated from API
  final RxString selectedCategory = ''.obs;
  final RxBool isLoadingProducts = false.obs;

  // Selected payment & discount
  final Rx<PaymentType> selectedPaymentType = PaymentType.cash.obs;
  final RxDouble globalDiscount = 0.0.obs;
  final RxnString selectedCustomerId = RxnString();
  final RxnString selectedCustomerName = RxnString();

  // Computed totals
  double get subtotal => cartItems.fold(0, (sum, item) => sum + item.totalPrice);
  double get total => subtotal - globalDiscount.value;
  int get totalItems => cartItems.fold(0, (sum, item) => sum + item.quantity);

  @override
  void onInit() {
    super.onInit();
    loadQuickAccessProducts();
    loadCategories();
  }

  // ── Quick Access Products ────────────────────────────────────────────────

  Future<void> loadCategories() async {
    try {
      final data = await ApiService.get('products/categories');
      categories.value = ['', ...(data as List).cast<String>()];
    } catch (_) {
      categories.value = [''];
    }
  }

  Future<void> loadQuickAccessProducts({String? category}) async {
    isLoadingProducts.value = true;
    try {
      final queryParams = category != null && category.isNotEmpty
          ? 'products?pageSize=24&category=${Uri.encodeComponent(category)}'
          : 'products?pageSize=24';
      final data = await ApiService.get(queryParams);
      final list = (data['data'] as List)
          .map((j) => ProductModel.fromJson(j as Map<String, dynamic>))
          .where((p) => p.stockQuantity > 0)
          .toList();
      quickAccessProducts.value = list;
    } catch (_) {
      quickAccessProducts.value = [];
    } finally {
      isLoadingProducts.value = false;
    }
  }

  void onCategorySelected(String cat) {
    selectedCategory.value = cat;
    loadQuickAccessProducts(category: cat);
  }

  void addProductToCart(ProductModel product) {
    if (product.stockQuantity <= 0) {
      errorMessage.value = 'المنتج "${product.name}" نفد من المخزن!';
      return;
    }
    _addToCart(product);
    lastScannedProduct.value = product;
  }

  /// Called when barcode is scanned or manually entered
  Future<void> onBarcodeScanned(String barcode) async {
    if (barcode.trim().isEmpty) return;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final data = await ApiService.get('products/barcode/$barcode');
      final product = ProductModel.fromJson(data);

      if (product.stockQuantity <= 0) {
        errorMessage.value = 'المنتج "${product.name}" نفد من المخزن!';
        return;
      }

      _addToCart(product);
      lastScannedProduct.value = product;
      lastScannedProductInfo.value = '${product.name} — ${product.price.toStringAsFixed(2)} ج.م';
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        errorMessage.value = 'لم يُعثر على منتج بالباركود: $barcode';
      } else {
        errorMessage.value = e.message;
      }
    } catch (e) {
      errorMessage.value = 'خطأ في الاتصال بالخادم';
    } finally {
      isLoading.value = false;
    }
  }

  void _addToCart(ProductModel product) {
    // Check if product already in cart — increment qty
    final existingIndex = cartItems.indexWhere((i) => i.productId == product.id);
    if (existingIndex != -1) {
      final existing = cartItems[existingIndex];
      cartItems[existingIndex] = CartItemModel(
        barcode: existing.barcode,
        productId: existing.productId,
        productName: existing.productName,
        unitPrice: existing.unitPrice,
        quantity: existing.quantity + 1,
      );
    } else {
      cartItems.insert(0, CartItemModel(
        barcode: product.globalBarcode,
        productId: product.id,
        productName: product.name,
        unitPrice: product.price,
      ));
    }
  }

  void removeFromCart(int index) {
    cartItems.removeAt(index);
  }

  void updateQuantity(int index, int newQty) {
    if (newQty <= 0) {
      removeFromCart(index);
      return;
    }
    final item = cartItems[index];
    cartItems[index] = CartItemModel(
      barcode: item.barcode,
      productId: item.productId,
      productName: item.productName,
      unitPrice: item.unitPrice,
      quantity: newQty,
      discount: item.discount,
      customPrice: item.customPrice,
    );
  }

  void updateCustomPrice(int index, double? newPrice) {
    if (index < 0 || index >= cartItems.length) return;
    final item = cartItems[index];
    cartItems[index] = CartItemModel(
      barcode: item.barcode,
      productId: item.productId,
      productName: item.productName,
      unitPrice: item.unitPrice,
      quantity: item.quantity,
      discount: item.discount,
      customPrice: newPrice,
    );
  }

  void clearCart() {
    cartItems.clear();
    globalDiscount.value = 0;
    lastScannedProduct.value = null;
    lastScannedProductInfo.value = '';
    errorMessage.value = '';
  }

  /// Submit the invoice to the backend and trigger receipt printing
  Future<bool> confirmCheckout(BuildContext context) async {
    if (cartItems.isEmpty) return false;
    isLoading.value = true;

    // Snapshot cart before clearing (for receipt)
    final itemsSnapshot = List<CartItemModel>.from(cartItems);
    final discountSnapshot = globalDiscount.value;

    try {
      final scannedItems = cartItems.expand((item) =>
        List.generate(item.quantity, (_) => {
          'barcode': item.barcode,
          if (item.customPrice != null) 'customPrice': item.customPrice,
        })
      ).toList();

      final body = {
        'scannedItems': scannedItems,
        'paymentType': selectedPaymentType.value.index,
        'customerId': selectedCustomerId.value,
        'discountAmount': discountSnapshot,
      };

      final result = await ApiService.post('invoices', body);

      final invoiceNo = result['invoiceNo'] as String? ?? '';
      final total = (result['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final paid = (result['paidAmount'] as num?)?.toDouble() ?? total;
      final remaining = (result['remainingAmount'] as num?)?.toDouble() ?? 0.0;
      final vat = (result['vatAmount'] as num?)?.toDouble() ?? 0.0;
      final double subTotal = (result['subTotal'] as num?)?.toDouble() ??
          itemsSnapshot.fold<double>(0.0, (s, i) => s + i.totalPrice);

      clearCart();

      _showSuccess(context, 'تم إنشاء الفاتورة $invoiceNo ✓\nالإجمالي: ${total.toStringAsFixed(2)} ج.م');

      // Print receipt asynchronously (won't block UI)
      ReceiptService.printReceipt(
        invoiceNo: invoiceNo,
        date: DateTime.now(),
        items: itemsSnapshot,
        subTotal: subTotal,
        discountAmount: discountSnapshot,
        vatAmount: vat,
        totalAmount: total,
        paidAmount: paid,
        remaining: remaining,
        paymentType: selectedPaymentType.value.index.toString(),
        customerName: selectedCustomerName.value,
      ).catchError((_) {}); // silent fail — user can reprint from invoices screen

      return true;
    } on ApiException catch (e) {
      _showError(context, e.message);
      return false;
    } catch (_) {
      _showError(context, 'خطأ في الاتصال بالخادم');
      return false;
    } finally {
      isLoading.value = false;
    }
  }


  void _showSuccess(BuildContext context, String msg) {
    ToastService.showSuccess(msg);
  }

  void _showError(BuildContext context, String msg) {
    ToastService.showError(msg);
  }

}
