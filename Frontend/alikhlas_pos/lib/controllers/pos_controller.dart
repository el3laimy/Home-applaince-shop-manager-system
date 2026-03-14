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
  final RxList<String> categories = <String>[].obs;
  final RxString selectedCategory = ''.obs;
  final RxBool isLoadingProducts = false.obs;

  // Selected payment & discount
  final Rx<PaymentType> selectedPaymentType = PaymentType.cash.obs;
  final RxDouble globalDiscount = 0.0.obs;
  final RxnString selectedCustomerId = RxnString();
  final RxnString selectedCustomerName = RxnString();

  // VAT values returned from API after checkout (BUG-01/02)
  final RxDouble vatAmount = 0.0.obs;
  final RxDouble vatRate = 0.0.obs;

  // UX-02: Name of the last product added — shows a brief visual badge in UI
  final RxString lastAddedProductName = ''.obs;

  // Last invoice id (used for installment schedule)
  String? _lastInvoiceId;

  // Last receipt data for reprinting
  final RxnString lastInvoiceNo = RxnString();
  Map<String, dynamic>? _lastReceiptData;
  bool get hasLastReceipt => _lastReceiptData != null;

  // Computed totals
  double get subtotal => cartItems.fold(0, (sum, item) => sum + item.totalPrice);
  double get total {
    // Task 3.2: Clamp discount to never exceed subtotal (prevent negative total)
    if (globalDiscount.value > subtotal) {
      globalDiscount.value = subtotal;
    }
    return subtotal - globalDiscount.value;
  }
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

      if (product.isLowStock) {
        Get.snackbar('تنبيه مخزون', 'المنتج "${product.name}" يوشك على النفاد. متبقي ${product.stockQuantity} فقط!',
            backgroundColor: const Color(0xFFF39C12), colorText: const Color(0xFFFFFFFF), duration: const Duration(seconds: 3));
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
      // Prevent adding more than available stock (BUG-10)
      if (existing.quantity >= product.stockQuantity) {
        _setError('لا يمكن تجاوز الكمية المتاحة في المخزن (${product.stockQuantity}) لمنتج "${product.name}"');
        return;
      }
      cartItems[existingIndex] = CartItemModel(
        barcode: existing.barcode,
        productId: existing.productId,
        productName: existing.productName,
        unitPrice: existing.unitPrice,
        quantity: existing.quantity + 1,
        stockQuantity: existing.stockQuantity,
      );
    } else {
      cartItems.insert(0, CartItemModel(
        barcode: product.globalBarcode.isNotEmpty ? product.globalBarcode : (product.internalBarcode ?? ''),
        productId: product.id,
        productName: product.name,
        unitPrice: product.price,
        // BUG-10: cast to int — product.stockQuantity is double in ProductModel
        stockQuantity: product.stockQuantity.toInt(),
      ));
    }
    // UX-02: Trigger brief visual confirmation badge
    lastAddedProductName.value = product.name;
    Future.delayed(const Duration(seconds: 2), () => lastAddedProductName.value = '');
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
    // BUG-10: Validate against known stock quantity
    if (newQty > item.stockQuantity && item.stockQuantity > 0) {
      _setError('الكمية المطلوبة تتجاوز المخزون المتاح (${item.stockQuantity}) لمنتج "${item.productName}"');
      return;
    }
    cartItems[index] = CartItemModel(
      barcode: item.barcode,
      productId: item.productId,
      productName: item.productName,
      unitPrice: item.unitPrice,
      quantity: newQty,
      discount: item.discount,
      customPrice: item.customPrice,
      stockQuantity: item.stockQuantity,
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
    vatAmount.value = 0;
    vatRate.value = 0;
    _lastInvoiceId = null;
    // Note: do NOT clear lastReceiptData here — user may want to reprint
    selectedPaymentType.value = PaymentType.cash;
  }

  /// Submit the invoice to the backend and trigger receipt printing
  /// [downPayment], [numberOfMonths], [interestRate], and [installmentPeriod] are used for installment invoices.
  Future<bool> confirmCheckout({
    double downPayment = 0.0,
    int numberOfMonths = 0,
    double interestRate = 0.0,
    int installmentPeriod = 0,  // 0=شهري 1=ربع 2=نصف 3=سنوي
    DateTime? firstInstallmentDate,
    String? paymentReference,
    double? splitCashAmount,
    double? splitVisaAmount,
  }) async {
    if (cartItems.isEmpty) return false;
    isLoading.value = true;

    // Snapshot cart before clearing (for receipt)
    final itemsSnapshot = List<CartItemModel>.from(cartItems);
    final discountSnapshot = globalDiscount.value;
    final paymentTypeSnapshot = selectedPaymentType.value;
    final customerIdSnapshot = selectedCustomerId.value;

    try {
      final scannedItems = cartItems.expand((item) =>
        List.generate(item.quantity, (_) {
          final map = <String, dynamic>{'barcode': item.barcode};
          if (item.customPrice != null) map['customPrice'] = item.customPrice;
          return map;
        })
      ).toList();

      final body = {
        'scannedItems': scannedItems,
        'paymentType': paymentTypeSnapshot.index,
        'customerId': customerIdSnapshot,
        'discountAmount': discountSnapshot,
        'downPayment': downPayment,
        'interestRate': interestRate,
        'installmentPeriod': installmentPeriod,
        'installmentCount': numberOfMonths,
        if (paymentReference != null && paymentReference.isNotEmpty) 'paymentReference': paymentReference,
        if (splitCashAmount != null && splitCashAmount > 0) 'splitCashAmount': splitCashAmount,
        if (splitVisaAmount != null && splitVisaAmount > 0) 'splitVisaAmount': splitVisaAmount,
      };

      final result = await ApiService.post('invoices', body);

      final invoiceId = result['id'] as String? ?? '';
      final invoiceNo = result['invoiceNo'] as String? ?? '';
      final total = (result['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final paid = (result['paidAmount'] as num?)?.toDouble() ?? total;
      final remaining = (result['remainingAmount'] as num?)?.toDouble() ?? 0.0;
      final vat = (result['vatAmount'] as num?)?.toDouble() ?? 0.0;
      final vatRateVal = (result['vatRate'] as num?)?.toDouble() ?? 0.0;
      final double subTotal = (result['subTotal'] as num?)?.toDouble() ??
          itemsSnapshot.fold<double>(0.0, (s, i) => s + i.totalPrice);

      // BUG-01/02: Store real VAT values from API
      vatAmount.value = vat;
      vatRate.value = vatRateVal;
      _lastInvoiceId = invoiceId;
      lastInvoiceNo.value = invoiceNo;

      // Snapshot receipt data for reprinting
      _lastReceiptData = {
        'invoiceNo': invoiceNo,
        'date': DateTime.now(),
        'items': List<CartItemModel>.from(itemsSnapshot),
        'subTotal': subTotal,
        'discountAmount': discountSnapshot,
        'vatAmount': vat,
        'totalAmount': total,
        'paidAmount': paid,
        'remaining': remaining,
        'paymentType': paymentTypeSnapshot.index.toString(),
        'customerName': selectedCustomerName.value,
      };

      clearCart();

      _showSuccess('تم إنشاء الفاتورة $invoiceNo ✓\nالإجمالي: ${total.toStringAsFixed(2)} ج.م');

      // BUG-05: Auto-create installment schedule after successful installment invoice
      if (paymentTypeSnapshot == PaymentType.installment &&
          remaining > 0 &&
          numberOfMonths > 0 &&
          customerIdSnapshot != null) {
        try {
          await ApiService.post('installments/schedule', {
            'invoiceId': invoiceId,
            'customerId': customerIdSnapshot,
            'downPayment': downPayment,
            'numberOfMonths': numberOfMonths,
            'firstInstallmentDate': (firstInstallmentDate ?? DateTime.now().add(const Duration(days: 30))).toIso8601String(),
          });
        } catch (_) {
          // Schedule creation failure is non-blocking
        }
      }

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
        paymentType: paymentTypeSnapshot.index.toString(),
        customerName: selectedCustomerName.value,
      ).catchError((_) {});

      return true;
    } on ApiException catch (e) {
      _showError(e.message);
      return false;
    } catch (_) {
      _showError('خطأ في الاتصال بالخادم');
      return false;
    } finally {
      isLoading.value = false;
    }
  }


  // UX-01: Auto-clear error message after 4 seconds
  void _setError(String msg) {
    errorMessage.value = msg;
    Future.delayed(const Duration(seconds: 4), () {
      if (errorMessage.value == msg) errorMessage.value = '';
    });
  }

  void _showSuccess(String msg) {
    ToastService.showSuccess(msg);
  }

  void _showError(String msg) {
    ToastService.showError(msg);
  }

  /// Reprint the last receipt using stored snapshot data
  Future<void> reprintLastReceipt() async {
    if (_lastReceiptData == null) return;
    final d = _lastReceiptData!;
    await ReceiptService.printReceipt(
      invoiceNo: d['invoiceNo'] as String,
      date: d['date'] as DateTime,
      items: d['items'] as List<CartItemModel>,
      subTotal: d['subTotal'] as double,
      discountAmount: d['discountAmount'] as double,
      vatAmount: d['vatAmount'] as double,
      totalAmount: d['totalAmount'] as double,
      paidAmount: d['paidAmount'] as double,
      remaining: d['remaining'] as double,
      paymentType: d['paymentType'] as String,
      customerName: d['customerName'] as String?,
    );
  }
}
