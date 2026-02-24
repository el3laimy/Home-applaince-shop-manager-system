// lib/models/installment_model.dart

enum InstallmentStatus { pending, paid, overdue }

class InstallmentModel {
  final String id;
  final String invoiceId;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final DateTime? paidAt;
  final String? notes;

  InstallmentStatus get status {
    if (isPaid) return InstallmentStatus.paid;
    if (DateTime.now().isAfter(dueDate)) return InstallmentStatus.overdue;
    return InstallmentStatus.pending;
  }

  InstallmentModel({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.dueDate,
    required this.isPaid,
    this.paidAt,
    this.notes,
  });

  factory InstallmentModel.fromJson(Map<String, dynamic> json) => InstallmentModel(
    id: json['id'] as String,
    invoiceId: json['invoiceId'] as String,
    amount: (json['amount'] as num).toDouble(),
    dueDate: DateTime.parse(json['dueDate'] as String),
    isPaid: json['isPaid'] as bool? ?? false,
    paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String) : null,
    notes: json['notes'] as String?,
  );
}

// lib/models/bridal_order_model.dart

class BridalOrderModel {
  final String id;
  final String brideName;
  final String? phone;
  final DateTime? weddingDate;
  final String status;
  final double totalAmount;
  final double paidAmount;
  final List<InstallmentModel> installments;

  double get remainingBalance => totalAmount - paidAmount;
  double get completionPercentage => totalAmount > 0 ? (paidAmount / totalAmount * 100).clamp(0, 100) : 0;

  BridalOrderModel({
    required this.id,
    required this.brideName,
    this.phone,
    this.weddingDate,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    this.installments = const [],
  });

  factory BridalOrderModel.fromJson(Map<String, dynamic> json) => BridalOrderModel(
    id: json['id'] as String,
    brideName: json['brideName'] as String? ?? json['customerName'] as String? ?? '',
    phone: json['phone'] as String?,
    weddingDate: json['weddingDate'] != null ? DateTime.parse(json['weddingDate'] as String) : null,
    status: json['status'] as String? ?? 'active',
    totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
    paidAmount: (json['paidAmount'] as num? ?? 0).toDouble(),
    installments: (json['installments'] as List<dynamic>? ?? [])
        .map((i) => InstallmentModel.fromJson(i as Map<String, dynamic>))
        .toList(),
  );
}
