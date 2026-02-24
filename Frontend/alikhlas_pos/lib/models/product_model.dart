// lib/models/product_model.dart

class ProductModel {
  final String id;
  final String name;
  final String globalBarcode;
  final String? internalBarcode;
  final String? description;
  final double purchasePrice;
  final double wholesalePrice;
  final double price; // retail/sale price
  final double stockQuantity;
  final double minStockAlert;
  final String? category;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isLowStock => stockQuantity <= minStockAlert;

  ProductModel({
    required this.id,
    required this.name,
    required this.globalBarcode,
    this.internalBarcode,
    this.description,
    required this.purchasePrice,
    required this.wholesalePrice,
    required this.price,
    required this.stockQuantity,
    this.minStockAlert = 5,
    this.category,
    this.imageUrl,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      globalBarcode: json['globalBarcode'] as String? ?? '',
      internalBarcode: json['internalBarcode'] as String?,
      description: json['description'] as String?,
      purchasePrice: (json['purchasePrice'] as num? ?? 0).toDouble(),
      wholesalePrice: (json['wholesalePrice'] as num? ?? 0).toDouble(),
      price: (json['price'] as num).toDouble(),
      stockQuantity: (json['stockQuantity'] as num).toDouble(),
      minStockAlert: (json['minStockAlert'] as num? ?? 5).toDouble(),
      category: json['category'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'globalBarcode': globalBarcode,
    'price': price,
    'purchasePrice': purchasePrice,
    'wholesalePrice': wholesalePrice,
    'stockQuantity': stockQuantity,
    'minStockAlert': minStockAlert,
    'category': category,
    'description': description,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };

  ProductModel copyWith({
    String? name,
    double? price,
    double? purchasePrice,
    double? wholesalePrice,
    double? stockQuantity,
    double? minStockAlert,
    String? category,
    String? description,
  }) {
    return ProductModel(
      id: id,
      name: name ?? this.name,
      globalBarcode: globalBarcode,
      internalBarcode: internalBarcode,
      description: description ?? this.description,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      price: price ?? this.price,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      category: category ?? this.category,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
