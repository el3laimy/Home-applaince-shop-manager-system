// lib/models/invoice_model.dart

enum PaymentType { cash, card, installment, visa, bankTransfer }
enum InvoiceStatus { completed, reserved }

class CartItemModel {
  final String barcode;
  final String productId;
  final String productName;
  final double unitPrice;
  int quantity;
  double? discount;
  double? customPrice;
  // BUG-10: track available stock for in-cart validation
  final int stockQuantity;

  CartItemModel({
    required this.barcode,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.quantity = 1,
    this.discount,
    this.customPrice,
    this.stockQuantity = 0,
  });

  double get effectivePrice => customPrice ?? unitPrice;
  double get totalPrice => (effectivePrice - (discount ?? 0)) * quantity;
}

class InvoiceItemModel {
  final String id;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  InvoiceItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) => InvoiceItemModel(
    id: json['id'] as String,
    productId: json['productId'] as String,
    productName: json['productName'] as String? ?? '',
    quantity: (json['quantity'] as num).toDouble(),
    unitPrice: (json['unitPrice'] as num).toDouble(),
    totalPrice: (json['totalPrice'] as num? ?? 0).toDouble(),
  );
}

class InvoiceModel {
  final String id;
  final String invoiceNo;
  final String? customerId;
  final String? customerName;
  final String? cashierName;
  final double subTotal;
  final double vatAmount;
  final double vatRate;
  final double totalAmount;
  final double? discountAmount;
  final double paidAmount;
  final double remainingAmount;
  final PaymentType paymentType;
  final InvoiceStatus status;
  final List<InvoiceItemModel> items;
  final DateTime createdAt;
  final String createdBy;

  InvoiceModel({
    required this.id,
    required this.invoiceNo,
    this.customerId,
    this.customerName,
    this.cashierName,
    required this.subTotal,
    required this.vatAmount,
    required this.vatRate,
    required this.totalAmount,
    this.discountAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentType,
    required this.status,
    required this.items,
    required this.createdAt,
    required this.createdBy,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) => InvoiceModel(
    id: json['id'] as String,
    invoiceNo: json['invoiceNo'] as String,
    customerId: json['customerId'] as String?,
    customerName: json['customerName'] as String?,
    cashierName: json['cashierName'] as String?,
    subTotal: (json['subTotal'] as num? ?? json['totalAmount'] as num? ?? 0).toDouble(),
    vatAmount: (json['vatAmount'] as num? ?? 0).toDouble(),
    vatRate: (json['vatRate'] as num? ?? 0).toDouble(),
    totalAmount: (json['totalAmount'] as num).toDouble(),
    discountAmount: (json['discountAmount'] as num?)?.toDouble(),
    paidAmount: (json['paidAmount'] as num? ?? json['totalAmount'] as num? ?? 0).toDouble(),
    remainingAmount: (json['remainingAmount'] as num? ?? 0).toDouble(),
    paymentType: PaymentType.values[json['paymentType'] as int? ?? 0],
    status: InvoiceStatus.values[json['status'] as int? ?? 0],
    items: (json['items'] as List<dynamic>? ?? []).map((i) => InvoiceItemModel.fromJson(i as Map<String, dynamic>)).toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    createdBy: json['createdBy'] as String? ?? '',
  );
}
