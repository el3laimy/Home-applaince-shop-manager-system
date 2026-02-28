// lib/models/supplier_model.dart

class SupplierModel {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? companyName;
  final double? openingBalance;
  final double? currentBalance;
  final double? totalPurchases;
  final double? totalPayments;
  final DateTime createdAt;

  SupplierModel({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.companyName,
    this.openingBalance,
    this.currentBalance,
    this.totalPurchases,
    this.totalPayments,
    required this.createdAt,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) => SupplierModel(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    address: json['address'] as String?,
    companyName: json['companyName'] as String?,
    openingBalance: (json['openingBalance'] as num?)?.toDouble(),
    currentBalance: (json['currentBalance'] as num?)?.toDouble(),
    totalPurchases: (json['totalPurchases'] as num?)?.toDouble(),
    totalPayments: (json['totalPayments'] as num?)?.toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
    'companyName': companyName,
    'openingBalance': openingBalance,
  };
}

// lib/models/purchase_invoice_model.dart

class PurchaseInvoiceItemModel {
  final String productId;
  final String? productName;
  final double quantity;
  final double unitCost;
  double get totalCost => quantity * unitCost;

  PurchaseInvoiceItemModel({
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitCost,
  });

  factory PurchaseInvoiceItemModel.fromJson(Map<String, dynamic> json) => PurchaseInvoiceItemModel(
    productId: json['productId'] as String,
    productName: json['productName'] as String?,
    quantity: (json['quantity'] as num).toDouble(),
    unitCost: (json['unitCost'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
    'unitCost': unitCost,
  };
}

class PurchaseInvoiceModel {
  final String? id;
  final String? supplierId;
  final String? supplierName;
  final String? referenceNumber;
  final double totalAmount;
  final double? paidAmount;
  final String? notes;
  final List<PurchaseInvoiceItemModel> items;
  final DateTime? createdAt;

  double get remainingBalance => totalAmount - (paidAmount ?? 0);

  PurchaseInvoiceModel({
    this.id,
    this.supplierId,
    this.supplierName,
    this.referenceNumber,
    required this.totalAmount,
    this.paidAmount,
    this.notes,
    required this.items,
    this.createdAt,
  });

  factory PurchaseInvoiceModel.fromJson(Map<String, dynamic> json) => PurchaseInvoiceModel(
    id: json['id'] as String?,
    supplierId: json['supplierId'] as String?,
    supplierName: json['supplierName'] as String?,
    referenceNumber: json['referenceNumber'] as String?,
    totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
    paidAmount: (json['paidAmount'] as num?)?.toDouble(),
    notes: json['notes'] as String?,
    items: (json['items'] as List<dynamic>? ?? []).map((i) => PurchaseInvoiceItemModel.fromJson(i as Map<String, dynamic>)).toList(),
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
  );
}
