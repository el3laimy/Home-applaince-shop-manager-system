// lib/models/customer_model.dart

class CustomerModel {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final double totalPurchases;
  final double totalPaid;
  final DateTime createdAt;

  double get balance => totalPurchases - totalPaid;

  CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    this.totalPurchases = 0,
    this.totalPaid = 0,
    required this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    address: json['address'] as String?,
    notes: json['notes'] as String?,
    totalPurchases: (json['totalPurchases'] as num? ?? 0).toDouble(),
    totalPaid: (json['totalPaid'] as num? ?? 0).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
    'notes': notes,
  };
}
